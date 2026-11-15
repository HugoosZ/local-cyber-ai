"""Apply EIAI model profiles inside the installed Open WebUI container."""

from __future__ import annotations

import asyncio
import base64
from contextlib import closing
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sqlite3
import sys


def validate_profiles(data: object) -> list[dict]:
    if not isinstance(data, list) or not data:
        raise ValueError('model-profiles.json debe contener una lista no vacia.')
    seen = set()
    for profile in data:
        if not isinstance(profile, dict):
            raise ValueError('Cada perfil debe ser un objeto.')
        model_id = profile.get('id', '')
        if not isinstance(model_id, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._:/-]*', model_id):
            raise ValueError('Identificador de modelo invalido.')
        if model_id in seen:
            raise ValueError('No se permiten perfiles duplicados.')
        seen.add(model_id)
        if not isinstance(profile.get('name'), str) or not profile['name'].strip():
            raise ValueError('Falta el nombre de un perfil.')
        params = profile.get('params')
        if not isinstance(params, dict):
            raise ValueError('Faltan los parametros de un perfil.')
        context = params.get('num_ctx')
        if type(context) is not int or context < 512:
            raise ValueError('El contexto de cada perfil debe ser un entero de al menos 512.')
        if type(params.get('think')) is not bool:
            raise ValueError('El parametro think de cada perfil debe ser booleano.')
    return data


def backup_database(database: Path) -> Path:
    if not database.is_file():
        raise RuntimeError('No existe la base de datos de WebUI.')
    folder = database.parent / 'backups'
    folder.mkdir(exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    target = folder / ('eiai-model-profiles-' + stamp + '.db')
    with closing(sqlite3.connect(database.as_uri() + '?mode=ro', uri=True)) as source:
        with closing(sqlite3.connect(target)) as destination:
            source.backup(destination)
    return target


async def apply_profiles(profiles: list[dict]) -> int:
    # The helper is copied to /tmp; WebUI's package lives outside that directory.
    sys.path.insert(0, '/app/backend')
    from open_webui.models.models import Models, ModelForm, ModelMeta, ModelParams
    from open_webui.models.users import Users

    admin = await Users.get_first_user()
    if admin is None:
        print('Crea tu administrador en WebUI y vuelve a ejecutar el inicio para aplicar los perfiles.')
        return 0
    if admin.role != 'admin':
        raise RuntimeError('La cuenta inicial no es administradora; no se modifican perfiles.')

    plans = []
    for profile in profiles:
        existing = await Models.get_model_by_id(profile['id'])
        if existing is not None and (existing.user_id != admin.id or existing.base_model_id is not None):
            raise RuntimeError('Existe un perfil ajeno o un alias con el mismo ID; no se modifica: ' + profile['id'])
        params = existing.params.model_dump() if existing else {}
        params.update(profile['params'])
        metadata = existing.meta.model_dump() if existing else {'description': profile.get('description', '')}
        metadata['capabilities'] = {**(metadata.get('capabilities') or {}), 'builtin_tools': False}
        name = existing.name if existing else profile['name']
        if existing and existing.params.model_dump() == params and existing.meta.model_dump() == metadata:
            continue
        form = ModelForm(
            id=profile['id'], base_model_id=None, name=name,
            params=ModelParams(**params), meta=ModelMeta(**metadata),
            access_grants=[], is_active=existing.is_active if existing else True,
            commit_message='Apply EIAI model profile',
        )
        plans.append((existing, form))

    if not plans:
        print('Perfiles de modelos ya actualizados.')
        return 0
    backup = backup_database(Path('/app/backend/data/webui.db'))
    for existing, form in plans:
        if existing:
            result = await Models.update_model_by_id(form.id, form, user_id=admin.id)
        else:
            result = await Models.insert_new_model(form, admin.id)
        if result is None:
            raise RuntimeError('No se pudo guardar el perfil: ' + form.id)
        print('Perfil aplicado: ' + form.name)
    print('Respaldo privado: ' + str(backup))
    return 0


def main() -> int:
    try:
        profiles = validate_profiles(json.loads(base64.b64decode(sys.argv[1], validate=True).decode('utf-8-sig')))
        return asyncio.run(apply_profiles(profiles))
    except Exception as error:
        print('ERROR al aplicar perfiles: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
