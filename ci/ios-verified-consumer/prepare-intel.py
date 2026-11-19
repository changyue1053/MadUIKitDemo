#!/usr/bin/env python3
"""Temporary Intel simulator build adapters; never mutate product Kotlin sources."""
import hashlib
from pathlib import Path
import sys

sdk, demo = map(Path, sys.argv[1:])
def sources(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*.kt')}
before = (sources(sdk), sources(demo))
for name in ('maduikit-theme', 'maduikit-components'):
    path = sdk/name/'build.gradle.kts'
    old = path.read_text()
    assert old.count('    iosArm64()\n') == 1 and 'iosX64()' not in old
    path.write_text(old.replace('    iosArm64()\n', '    iosArm64()\n    iosX64() // isolated Intel CI adapter\n'))
p = demo/'composeApp/build.gradle.kts'
s = p.read_text()
assert s.count('listOf(iosArm64(), iosSimulatorArm64())') == 1
s = s.replace('listOf(iosArm64(), iosSimulatorArm64())', 'listOf(iosArm64(), iosSimulatorArm64(), iosX64())')
s += '''
// Isolated Intel CI adapter: check actual resolved SDK binaries against the stage.
tasks.register("verifyStagedIosX64Sdk") {
    doLast {
        val expectedVersion = "0.1.0-alpha01"
        val modules = setOf("maduikit-components-iosx64", "maduikit-theme-iosx64")
        val resolved = configurations.getByName("iosX64CompileKlibraries").incoming.artifacts.artifacts
            .mapNotNull { a -> (a.id.componentIdentifier as? ModuleComponentIdentifier)
                ?.takeIf { it.group == "com.mad.maduikit" }?.let { it to a.file } }
        check(resolved.size == 2 && resolved.map { it.first.module }.toSet() == modules)
        fun digest(f: File) = MessageDigest.getInstance("SHA-256").digest(f.readBytes())
            .joinToString("") { (it.toInt() and 255).toString(16).padStart(2, '0') }
        val stage = rootProject.file(providers.gradleProperty("maduikitStagingDir").get())
        for ((id, file) in resolved) {
            val staged = stage.resolve("com/mad/maduikit/${id.module}/$expectedVersion/${id.module}-$expectedVersion.klib")
            check(id.version == expectedVersion && file.extension == "klib" && staged.isFile)
            check(digest(staged) == digest(file))
            println("Verified external iOS x64 SDK module $id sha256=${digest(file)}")
        }
    }
}
'''
p.write_text(s)
assert before == (sources(sdk), sources(demo)), 'Kotlin product sources changed'
print('Isolated iosX64 adapters prepared; all product .kt files byte-identical.')
