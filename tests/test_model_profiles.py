import importlib.util
from contextlib import closing
from pathlib import Path
import sqlite3
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('model_profiles', ROOT / 'scripts' / 'model_profiles.py')
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class ProfileTests(unittest.TestCase):
    def test_rejects_duplicate_models_and_invalid_context(self):
        profile = {'id': 'gemma4:12b', 'name': 'Gemma', 'params': {'num_ctx': 8192, 'think': True}}
        with self.assertRaises(ValueError):
            module.validate_profiles([profile, profile])
        with self.assertRaises(ValueError):
            module.validate_profiles([{**profile, 'params': {'num_ctx': 0, 'think': True}}])

    def test_backup_includes_committed_wal_and_does_not_change_source(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'webui.db'
            with closing(sqlite3.connect(source)) as connection:
                connection.execute('PRAGMA journal_mode=WAL')
                connection.execute('CREATE TABLE example(value TEXT)')
                connection.execute('INSERT INTO example VALUES (?)', ('preserved',))
                connection.commit()
                backup = module.backup_database(source)
                with closing(sqlite3.connect(backup)) as copy:
                    self.assertEqual(copy.execute('SELECT value FROM example').fetchone(), ('preserved',))
                self.assertEqual(connection.execute('SELECT value FROM example').fetchone(), ('preserved',))

    def test_missing_database_is_not_created(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / 'missing.db'
            with self.assertRaises(RuntimeError):
                module.backup_database(database)
            self.assertFalse(database.exists())


if __name__ == '__main__':
    unittest.main()
