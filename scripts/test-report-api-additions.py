#!/usr/bin/env python3
"""Run reporter regressions; add --compiler-fixture on macOS to check digester metadata."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import unittest


sys.dont_write_bytecode = True
REPORTER_PATH = Path(__file__).with_name("report-api-additions.py")
SPEC = importlib.util.spec_from_file_location("report_api_additions", REPORTER_PATH)
REPORTER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = REPORTER
SPEC.loader.exec_module(REPORTER)

RUN_COMPILER_FIXTURE = "--compiler-fixture" in sys.argv
if RUN_COMPILER_FIXTURE:
    sys.argv.remove("--compiler-fixture")


def declaration(name: str, kind: str = "Function", **fields) -> dict:
    return {"kind": kind, "name": name, "usr": f"s:{name}", **fields}


def write_dump(directory: Path, module: str, children: list[dict]) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{module}.json"
    path.write_text(json.dumps({"ABIRoot": {"kind": "Root", "children": children}}))
    return path


def report(base: Path, head: Path, sources: Path, module: str, count: Path) -> str:
    return subprocess.run(
        [sys.executable, str(REPORTER_PATH), str(base), str(head), str(sources),
         module, "--count-file", str(count)],
        check=True, capture_output=True, text=True,
    ).stdout


class DeclarationTests(unittest.TestCase):
    def test_public_and_open_with_absent_or_false_internal_flag(self):
        nodes = [
            declaration("public"),
            declaration("explicitFalse", isInternal=False),
            declaration("open", isOpen=True),
            declaration("package", isInternal=True),
        ]
        self.assertEqual(
            [item.name for item in REPORTER.collect_declarations(nodes, "Fixture")],
            ["public", "explicitFalse", "open"],
        )

    def test_hidden_parent_prunes_public_descendants_and_preserves_siblings(self):
        nodes = [
            declaration("Hidden", "TypeDecl", isInternal=True, children=[
                declaration("PublicNested", "TypeDecl", children=[
                    declaration("publicGrandchild"),
                ]),
                declaration("publicMember"),
            ]),
            declaration("Visible", "TypeDecl", children=[declaration("publicSibling")]),
        ]
        self.assertEqual(
            [item.usr for item in REPORTER.collect_declarations(nodes, "Fixture")],
            ["s:Visible", "s:publicSibling"],
        )

    def test_external_type_keeps_our_public_extension_members(self):
        node = declaration("String", "TypeDecl", moduleName="Swift", children=[
            declaration("publicExtension", moduleName="Fixture"),
            declaration("packageExtension", moduleName="Fixture", isInternal=True),
        ])
        self.assertEqual(
            [item.usr for item in REPORTER.collect_declarations(node, "Fixture")],
            ["s:publicExtension"],
        )

    def test_public_report_and_hash_ignore_package_additions(self):
        expected = (
            "==============================================================\n"
            " PUBLIC API additions since baseline\n"
            "==============================================================\n"
            "1 added declaration(s).\n\n"
            "Sources/Fixture\n"
            "  Fixture.swift\n"
            "    - func stableAddition()\n\n"
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sources = root / "Sources"
            module_sources = sources / "Fixture"
            module_sources.mkdir(parents=True)
            (module_sources / "Fixture.swift").write_text(
                "public func stableAddition() {}\npackage func packageHelper() {}\n"
            )
            write_dump(root / "base", "Fixture", [])
            for package_nodes in ([], [declaration("packageHelper", isInternal=True)]):
                with self.subTest(package_nodes=bool(package_nodes)):
                    write_dump(root / "head", "Fixture", [
                        declaration("stableAddition", printedName="stableAddition()"),
                        *package_nodes,
                    ])
                    output = report(root / "base", root / "head", sources,
                                    "Fixture", root / "count.txt")
                    self.assertEqual(output, expected)
                    self.assertEqual((root / "count.txt").read_text(), "1\n")
                    self.assertEqual(hashlib.sha256(output.encode()).hexdigest()[:12],
                                     "3d6118d71c00")


COMPILER_SOURCE = """\
public struct Visible: Equatable {
    public private(set) var value: Int = 1
    public init() {}
    public func overload(_ value: Int) {}
    package func overload(_ value: String) {}
    func internalMember() {}
    fileprivate func fileprivateMember() {}
    private func privateMember() {}
    public subscript(_ value: Int) -> Int { value }
    package subscript(_ value: String) -> Int { 0 }
    public struct Nested {
        public var visibleProperty: Int { 0 }
        package var packageProperty: Int { 0 }
    }
    package struct HiddenNested {
        public var publicMember: Int { 0 }
    }
}
public extension Visible {
    func inheritedPublic() {}
    package func packageInPublicExtension() {}
    internal func internalInPublicExtension() {}
}
package extension Visible {
    func inheritedPackage() {}
}
extension Visible {
    public func explicitPublic() {}
    func implicitInternal() {}
}
private extension Visible {
    func inheritedPrivate() {}
}
package struct HiddenParent {
    public struct PublicNested {
        public var publicGrandchild: Int { 0 }
    }
    public func publicMember() {}
}
struct InternalParent {
    public func publicMember() {}
}
public protocol Contract {
    associatedtype Item
    var requirement: Item { get }
    func requiredMethod()
}
package protocol HiddenContract {
    var packageRequirement: Int { get }
}
public enum PublicEnum { case example }
package enum HiddenEnum { case example }
open class OpenClass {
    public init() {}
    open func openMethod() {}
    public func publicMethod() {}
    package func packageMethod() {}
}
public typealias PublicAlias = Visible
package typealias HiddenAlias = Visible
package func packageFunction() {}
internal func internalFunction() {}
fileprivate func fileprivateFunction() {}
private func privateFunction() {}
@usableFromInline internal func usableFromInlineFunction() {}
@_spi(Tests) public func spiFunction() {}
extension String {
    public func externalPublic() {}
    package func externalPackage() {}
}
"""


@unittest.skipUnless(RUN_COMPILER_FIXTURE, "add --compiler-fixture to verify Swift metadata")
class CompilerFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if sys.platform != "darwin":
            raise RuntimeError("--compiler-fixture requires macOS and Xcode")
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.module = "VisibilityFixture"
        cls.target = f"{platform.machine()}-apple-macosx15.0"
        cls.dumps = {}
        cls.raw = {}
        for revision, additions in (
            ("base", "package func promoted() {}\n"),
            ("head", "public func promoted() {}\npublic func newPublicAPI() {}\n"
                     "package func newPackageHelper() {}\n"),
        ):
            directory = cls.root / revision
            directory.mkdir()
            source = directory / "Sources" / cls.module / "Fixture.swift"
            source.parent.mkdir(parents=True)
            source.write_text(COMPILER_SOURCE + additions)
            dump = directory / f"{cls.module}.json"
            common = ["-target", cls.target, "-module-cache-path", str(cls.root / "cache")]
            commands = [
                ["xcrun", "swiftc", "-emit-module", "-parse-as-library",
                 "-module-name", cls.module, "-package-name", "VisibilityTests",
                 *common, "-emit-module-path", str(directory / f"{cls.module}.swiftmodule"),
                 str(source)],
                ["xcrun", "swift-api-digester", "-dump-sdk", "-avoid-location",
                 "-avoid-tool-args", "-module", cls.module, "-I", str(directory),
                 *common, "-o", str(dump)],
            ]
            for command in commands:
                result = subprocess.run(command, capture_output=True, text=True)
                if result.returncode:
                    raise RuntimeError(f"{command!r}\n{result.stdout}{result.stderr}")
            cls.dumps[revision] = dump
            cls.raw[revision] = json.loads(dump.read_text())["ABIRoot"]

    def test_compiler_access_contract_and_public_surface(self):
        raw_nodes = {}

        def visit(node, context=()):
            if node.get("kind") in REPORTER.DECLARATION_KINDS:
                raw_nodes[context + (node["name"],)] = node
            child_context = context + (node["name"],) if node.get("kind") == "TypeDecl" else context
            for child in node.get("children", []):
                visit(child, child_context)

        visit(self.raw["base"])
        self.assertIs(raw_nodes[("Visible", "inheritedPackage")]["isInternal"], True)
        self.assertIs(raw_nodes[("Visible", "packageInPublicExtension")]["isInternal"], True)
        self.assertIs(raw_nodes[("HiddenParent",)]["isInternal"], True)
        self.assertFalse(raw_nodes[("HiddenParent", "PublicNested")].get("isInternal", False))
        self.assertFalse(raw_nodes[("HiddenParent", "publicMember")].get("isInternal", False))
        for name in ("internalFunction", "fileprivateFunction", "privateFunction",
                     "usableFromInlineFunction", "InternalParent"):
            self.assertNotIn((name,), raw_nodes)
        self.assertIs(raw_nodes[("OpenClass",)]["isOpen"], True)
        self.assertIs(raw_nodes[("OpenClass", "openMethod")]["isOpen"], True)

        public = REPORTER.public_declarations(self.dumps["base"], self.module)
        visible = next(node for node in self.raw["base"]["children"] if node.get("name") == "Visible")
        for name in ("overload", "subscript"):
            overloads = [node for node in visible["children"] if node.get("name") == name]
            self.assertEqual(len(overloads), 2)
            for node in overloads:
                self.assertEqual(node["usr"] in public, not node.get("isInternal", False))
        labels = [".".join(item.context + (item.printed_name,)) for item in public.values()]
        expected = {
            "Visible", "Visible.value", "Visible.init()", "Visible.overload(_:)",
            "Visible.subscript(_:)", "Visible.Nested", "Visible.Nested.visibleProperty",
            "Visible.__derived_struct_equals(_:_:)", "Visible.inheritedPublic()",
            "Visible.explicitPublic()", "Contract", "Contract.Item", "Contract.requirement",
            "Contract.requiredMethod()", "PublicEnum", "PublicEnum.example",
            "PublicEnum.__derived_enum_equals(_:_:)", "PublicEnum.hash(into:)",
            "PublicEnum.hashValue", "OpenClass", "OpenClass.init()", "OpenClass.openMethod()",
            "OpenClass.publicMethod()", "PublicAlias", "spiFunction()",
            "String.externalPublic()",
        }
        self.assertEqual(set(labels), expected)
        self.assertEqual(len(labels), len(expected))  # Overloads have the same printed name.

    def test_same_usr_promotion_and_report(self):
        before = next(node for node in self.raw["base"]["children"] if node.get("name") == "promoted")
        after = next(node for node in self.raw["head"]["children"] if node.get("name") == "promoted")
        self.assertEqual(before["usr"], after["usr"])
        self.assertIs(before["isInternal"], True)
        self.assertFalse(after.get("isInternal", False))
        baseline = REPORTER.public_declarations(self.dumps["base"], self.module)
        current = REPORTER.public_declarations(self.dumps["head"], self.module)
        self.assertEqual({current[usr].name for usr in current.keys() - baseline.keys()},
                         {"promoted", "newPublicAPI"})
        output = report(self.root / "base", self.root / "head", self.root / "head/Sources",
                        self.module, self.root / "count.txt")
        self.assertEqual((self.root / "count.txt").read_text(), "2\n")
        self.assertIn("    - func promoted()\n", output)
        self.assertIn("    - func newPublicAPI()\n", output)
        self.assertNotIn("newPackageHelper", output)
        reverse = report(self.root / "head", self.root / "base", self.root / "base/Sources",
                         self.module, self.root / "reverse-count.txt")
        self.assertEqual((self.root / "reverse-count.txt").read_text(), "0\n")
        self.assertIn("No public API additions detected.", reverse)


if __name__ == "__main__":
    unittest.main(verbosity=2)
