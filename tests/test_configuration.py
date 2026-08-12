from __future__ import annotations

import json
import re
import unittest
import xml.etree.ElementTree as ElementTree
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PACKAGE_ROOT = REPOSITORY_ROOT / "package"


class ConfigurationSchemaTests(unittest.TestCase):
    def test_every_configuration_default_is_explicit(self) -> None:
        expected = {
            "widgetTitle": "TTop Desk",
            "showCpu": "true",
            "showMemory": "true",
            "showNetwork": "true",
            "showTemperature": "true",
            "showFilesystems": "true",
            "showDiskIo": "true",
            "showProcesses": "true",
            "showGpu": "true",
            "showHeader": "true",
            "showMetricIcons": "true",
            "showSectionLabels": "true",
            "showCpuProgressBar": "true",
            "showMemoryProgressBar": "true",
            "showFilesystemProgressBars": "true",
            "showProcessCpu": "true",
            "showProcessMemory": "true",
            "showGpuUtilization": "true",
            "showGpuMemory": "true",
            "showGpuTemperature": "true",
            "showGpuProgressBars": "true",
            "showGraphs": "true",
            "showCpuGraph": "true",
            "showMemoryGraph": "true",
            "showGpuGraph": "true",
            "showNetworkGraph": "true",
            "showNetworkRx": "true",
            "showNetworkTx": "true",
            "showDiskRead": "true",
            "showDiskWrite": "true",
            "compactSpacing": "false",
            "denseMode": "false",
            "compactModeDetails": "false",
            "refreshIntervalMs": "1000",
            "filesystemRefreshIntervalMs": "15000",
            "maximumFilesystemEntries": "3",
            "maximumProcessEntries": "5",
            "processSortMode": "cpu",
            "processRefreshIntervalMs": "2000",
            "gpuRefreshIntervalMs": "1000",
            "historySampleCount": "60",
            "backgroundOpacity": "1.0",
            "usePlasmaThemeBackground": "true",
            "customBackgroundColor": "#20252b",
        }
        tree = ElementTree.parse(PACKAGE_ROOT / "contents/config/main.xml")
        namespace = {"k": "http://www.kde.org/standards/kcfg/1.0"}
        actual = {
            entry.attrib["name"]: entry.findtext("k:default", namespaces=namespace)
            for entry in tree.findall(".//k:entry", namespace)
        }
        self.assertEqual(actual, expected)

    def test_configuration_page_contains_seven_groups(self) -> None:
        model = (PACKAGE_ROOT / "contents/config/config.qml").read_text(
            encoding="utf-8"
        )
        sources = re.findall(r'source:\s*"([^"]+)"', model)
        self.assertEqual(sources, ["ConfigGeneral.qml"])
        for source in sources:
            self.assertTrue((PACKAGE_ROOT / "contents/ui" / source).is_file())
        page = (PACKAGE_ROOT / "contents/ui/ConfigGeneral.qml").read_text(
            encoding="utf-8"
        )
        for heading in ("General", "Display", "Metrics", "Graphs", "Processes", "Refresh", "Appearance"):
            self.assertIn(f'text: qsTr("{heading}")', page)

    def test_plugin_identity_is_unchanged(self) -> None:
        metadata = json.loads((PACKAGE_ROOT / "metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(metadata["KPlugin"]["Id"], "io.github.s3cb34r.ttopdesk")
        self.assertEqual(metadata["KPlugin"]["Version"], "0.1.13")


if __name__ == "__main__":
    unittest.main()
