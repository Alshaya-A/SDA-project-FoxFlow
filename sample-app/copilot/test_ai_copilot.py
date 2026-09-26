import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("ai_copilot.py")
SPEC = importlib.util.spec_from_file_location("ai_copilot", MODULE_PATH)
COPILOT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COPILOT)


class CopilotSafetyTests(unittest.TestCase):
    def setUp(self):
        self.tools = {
            "check_status": {"arguments": {}},
            "run_backup": {"arguments": {}},
            "get_pipeline": {"arguments": {}},
            "read_logs": {"arguments": {"service": ["gitlab", "app", "runner"]}},
            "restart_service": {"arguments": {"service": ["gitlab", "app", "runner"]}},
        }

    def test_arabic_requests_map_to_approved_tools(self):
        self.assertEqual(COPILOT.local_decision("كيف حال المشروع؟")["tool"], "check_status")
        self.assertEqual(COPILOT.local_decision("خذ نسخة احتياطية الآن")["tool"], "run_backup")
        self.assertEqual(COPILOT.local_decision("ليش البايب لاين فشل؟")["tool"], "get_pipeline")

    def test_model_cannot_invent_tool_or_service(self):
        with self.assertRaises(ValueError):
            COPILOT.validate_decision({"tool": "shell", "arguments": {"cmd": "id"}}, self.tools)
        with self.assertRaises(ValueError):
            COPILOT.validate_decision(
                {"tool": "restart_service", "arguments": {"service": "docker"}}, self.tools
            )

    def test_sensitive_values_are_redacted(self):
        clean = COPILOT.clean_text(
            "Authorization: Bearer abc123\nBOT_TOKEN=123456:abcdefghijklmnopqrstuvwxyz"
        )
        self.assertNotIn("abc123", clean)
        self.assertNotIn("abcdefghijklmnopqrstuvwxyz", clean)


if __name__ == "__main__":
    unittest.main()
