"""Run with LINKERD_VIZ_CHART=/path/to/linkerd-viz-2025.10.7.tgz python3 -m unittest discover -s tests -p 'test_*.py'."""
import copy
import os
from pathlib import Path
import subprocess
import unittest

import yaml


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/without-cadvisor.sh"


class CadvisorRenderer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        chart = os.environ["LINKERD_VIZ_CHART"]
        cls.original = subprocess.run(
            ["helm", "template", "linkerd-viz", chart, "--namespace", "test-viz"],
            check=True, text=True, capture_output=True,
        ).stdout

    def render(self, source, namespace="test-viz"):
        return subprocess.run(
            ["/bin/sh", str(SCRIPT), namespace], input=source,
            text=True, capture_output=True,
        )

    def test_only_the_cadvisor_job_changes(self):
        result = self.render(self.original)
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = list(yaml.safe_load_all(self.original))
        actual = list(yaml.safe_load_all(result.stdout))
        target = next(d for d in expected if d and d.get("kind") == "ConfigMap"
                      and d["metadata"]["name"] == "prometheus-config")
        config = yaml.safe_load(target["data"]["prometheus.yml"])
        original_jobs = copy.deepcopy(config["scrape_configs"])
        config["scrape_configs"] = [j for j in original_jobs
                                    if j["job_name"] != "kubernetes-nodes-cadvisor"]
        self.assertEqual(len(original_jobs) - len(config["scrape_configs"]), 1)
        target["data"]["prometheus.yml"] = config
        for doc in actual:
            if doc and doc.get("kind") == "ConfigMap" and doc["metadata"]["name"] == "prometheus-config":
                doc["data"]["prometheus.yml"] = yaml.safe_load(doc["data"]["prometheus.yml"])
        self.assertEqual(actual, expected)

    def test_unrecognized_layout_emits_no_partial_output(self):
        result = self.render(self.original.replace("kubernetes-nodes-cadvisor", "renamed-job"))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_wrong_namespace_fails_closed(self):
        result = self.render(self.original, "other-viz")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_duplicate_jobs_fail_closed(self):
        result = self.render(self.original + "\n" + self.original)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
