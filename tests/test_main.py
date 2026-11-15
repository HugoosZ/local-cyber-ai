"""Launcher checks without starting Docker, downloading models or opening a browser."""

from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import URLError


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("eiai_launcher", ROOT / "main.py")
assert SPEC and SPEC.loader
launcher = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(launcher)


class PortTests(unittest.TestCase):
    def test_missing_file_or_setting_uses_default(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = Path(directory) / ".env"
            self.assertEqual(launcher.read_port(environment), 3000)
            environment.write_text("PRIMARY_MODEL=example:9b\n", encoding="utf-8")
            self.assertEqual(launcher.read_port(environment), 3000)

    def test_custom_port_with_quotes_comments_and_last_assignment(self):
        variants = [
            "WEBUI_PORT=3100 # personal\n",
            "WEBUI_PORT='3100' # personal\n",
            'WEBUI_PORT = "3100"\n',
            "WEBUI_PORT=3000\nWEBUI_PORT=3100\n",
        ]
        with tempfile.TemporaryDirectory() as directory:
            environment = Path(directory) / ".env"
            for content in variants:
                with self.subTest(content=content):
                    environment.write_text(content, encoding="utf-8-sig")
                    self.assertEqual(launcher.read_port(environment), 3100)

    def test_invalid_port_is_not_silently_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = Path(directory) / ".env"
            for value in ("", "0", "65536", "abc", "3000#comment", "'3000", '"3000"evil'):
                with self.subTest(value=value):
                    environment.write_text(f"WEBUI_PORT={value}\n", encoding="utf-8")
                    with self.assertRaises(ValueError):
                        launcher.read_port(environment)


class StartupTests(unittest.TestCase):
    def test_powershell_uses_argument_list_and_absolute_root_even_from_other_directory(self):
        with tempfile.TemporaryDirectory(prefix="eiai project ") as directory:
            root = Path(directory).resolve()
            scripts = root / "scripts"
            scripts.mkdir()
            (scripts / "Start-LocalAI.ps1").write_text("# fixture\n", encoding="utf-8")
            original = Path.cwd()
            try:
                os.chdir(scripts)
                with patch.object(launcher, "powershell_path", return_value=r"C:\Windows\powershell.exe"), patch.object(
                    launcher.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)
                ) as run:
                    self.assertEqual(launcher.start_stack(root, True), 0)
            finally:
                os.chdir(original)
            command = run.call_args.args[0]
            self.assertEqual(command[-2:], [str(scripts / "Start-LocalAI.ps1"), "-WithComparison"])
            self.assertEqual(run.call_args.kwargs, {"cwd": str(root), "check": False})
            self.assertNotIn("shell", run.call_args.kwargs)


class ModelTests(unittest.TestCase):
    def test_missing_file_or_setting_uses_default(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = Path(directory) / ".env"
            self.assertEqual(launcher.read_primary_model(environment), "gemma4:12b")
            environment.write_text("WEBUI_PORT=3100\n", encoding="utf-8")
            self.assertEqual(launcher.read_primary_model(environment), "gemma4:12b")

    def test_custom_model_with_quotes_comments_and_last_assignment(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = Path(directory) / ".env"
            environment.write_text(
                "WEBUI_SECRET_KEY=private-fixture-value\n"
                "PRIMARY_MODEL=gemma4:12b\n"
                "PRIMARY_MODEL='huihui_ai/gemma4-abliterated:12b' # personal\n",
                encoding="utf-8-sig",
            )
            self.assertEqual(
                launcher.read_primary_model(environment), "huihui_ai/gemma4-abliterated:12b"
            )

    def test_invalid_model_is_not_silently_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = Path(directory) / ".env"
            for value in ("", "model name", "/model", "model?tools=anything", "'model", '"model"extra'):
                with self.subTest(value=value):
                    environment.write_text(f"PRIMARY_MODEL={value}\n", encoding="utf-8")
                    with self.assertRaises(ValueError):
                        launcher.read_primary_model(environment)


class MainTests(unittest.TestCase):
    def run_main(self, arguments=(), *, startup_return=0, health_error=None, port=3100, model=None):
        with tempfile.TemporaryDirectory(prefix="eiai project ") as directory:
            root = Path(directory)
            content = f"WEBUI_PORT={port}\nWEBUI_SECRET_KEY=private-fixture-value\n"
            if model is not None:
                content += f"PRIMARY_MODEL={model}\n"
            (root / ".env").write_text(content, encoding="utf-8")
            with patch.object(launcher.sys, "platform", "win32"), patch.object(
                launcher, "start_stack", return_value=startup_return
            ) as startup, patch.object(
                launcher, "wait_for_health", side_effect=health_error
            ) as health, patch.object(launcher.webbrowser, "open", return_value=True) as browser, redirect_stdout(
                io.StringIO()
            ) as stdout, redirect_stderr(io.StringIO()) as stderr:
                code = launcher.main(list(arguments), project_root=root)
            return code, startup, health, browser, stdout.getvalue(), stderr.getvalue()

    def test_success_opens_named_url_after_health(self):
        code, startup, health, browser, stdout, _ = self.run_main()
        self.assertEqual(code, 0)
        self.assertFalse(startup.call_args.args[1])
        health.assert_called_once_with(3100)
        browser.assert_called_once_with("http://eiai.localhost:3100/?model=gemma4%3A12b", new=2)
        self.assertIn("http://eiai.localhost:3100/?model=gemma4%3A12b", stdout)
        self.assertNotIn("private-fixture-value", stdout)

    def test_custom_model_is_urlencoded_and_does_not_expose_other_settings(self):
        code, _, health, browser, stdout, stderr = self.run_main(
            model="huihui_ai/gemma4-abliterated:12b"
        )
        self.assertEqual(code, 0)
        health.assert_called_once_with(3100)
        browser.assert_called_once_with(
            "http://eiai.localhost:3100/?model=huihui_ai%2Fgemma4-abliterated%3A12b", new=2
        )
        self.assertNotIn("private-fixture-value", stdout + stderr)

    def test_start_failure_preserves_exit_and_never_opens_browser(self):
        code, _, health, browser, _, _ = self.run_main(startup_return=7)
        self.assertEqual(code, 7)
        health.assert_not_called()
        browser.assert_not_called()

    def test_health_failure_never_opens_browser(self):
        code, _, _, browser, _, stderr = self.run_main(health_error=RuntimeError("not ready"))
        self.assertEqual(code, 1)
        browser.assert_not_called()
        self.assertIn("not ready", stderr)

    def test_no_browser_and_comparison_flags(self):
        code, startup, health, browser, _, _ = self.run_main(("--no-browser", "--with-comparison"))
        self.assertEqual(code, 0)
        self.assertTrue(startup.call_args.args[1])
        health.assert_called_once_with(3100)
        browser.assert_not_called()

    def test_invalid_port_does_not_open_browser(self):
        code, _, health, browser, _, _ = self.run_main(port="invalid")
        self.assertEqual(code, 1)
        health.assert_not_called()
        browser.assert_not_called()

    def test_invalid_model_does_not_open_browser_or_check_health(self):
        code, _, health, browser, _, stderr = self.run_main(model="model?tools=anything")
        self.assertEqual(code, 1)
        health.assert_not_called()
        browser.assert_not_called()
        self.assertIn("PRIMARY_MODEL", stderr)
        self.assertNotIn("private-fixture-value", stderr)


class HealthTests(unittest.TestCase):
    def test_check_uses_loopback_and_disables_environment_proxies(self):
        response = MagicMock()
        response.__enter__.return_value.getcode.return_value = 200
        opener = MagicMock()
        opener.open.return_value = response
        with patch.object(launcher, "ProxyHandler") as handler, patch.object(
            launcher, "build_opener", return_value=opener
        ):
            launcher.wait_for_health(3100)
        handler.assert_called_once_with({})
        self.assertEqual(opener.open.call_args.args[0], "http://127.0.0.1:3100/health")

    def test_check_fails_after_deadline(self):
        opener = MagicMock()
        opener.open.side_effect = URLError("unavailable")
        with patch.object(launcher, "build_opener", return_value=opener), patch.object(
            launcher.time, "monotonic", side_effect=[0.0, 0.1, 30.1]
        ):
            with self.assertRaisesRegex(RuntimeError, "unavailable"):
                launcher.wait_for_health(3100)


if __name__ == "__main__":
    unittest.main()
