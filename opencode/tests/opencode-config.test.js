import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const requiredCommands = ["opsx-explore", "opsx-propose", "opsx-apply", "opsx-archive"];
const requiredOrchestrators = [
  "opsx-explore-orchestrator",
  "opsx-propose-orchestrator",
  "opsx-apply-orchestrator",
  "opsx-archive-orchestrator"
];
const requiredSubagents = [
  "opsx-implementer",
  "opsx-test-fixer",
  "opsx-code-reviewer",
  "opsx-docs-refactor"
];

function getFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  return match ? match[1] : "";
}

function getTopLevelField(frontmatter, key) {
  const regex = new RegExp(`^${key}:\\s*(.+)$`, "m");
  const match = frontmatter.match(regex);
  return match ? match[1].trim() : null;
}

test("opencode.json configures OpenRouter provider with env-backed key", () => {
  const raw = fs.readFileSync("opencode.json", "utf8");
  const config = JSON.parse(raw);

  assert.ok(config.provider?.openrouter, "missing openrouter provider config");
  assert.equal(
    config.provider.openrouter.options.apiKey,
    "{env:OPENROUTER_API_KEY}",
    "openrouter apiKey should come from env"
  );
});

test("agent markdown files exist and declare required roles", () => {
  for (const name of [...requiredOrchestrators, ...requiredSubagents]) {
    const file = path.join(".opencode", "agents", `${name}.md`);
    assert.ok(fs.existsSync(file), `missing agent file ${file}`);

    const fm = getFrontmatter(fs.readFileSync(file, "utf8"));
    assert.ok(getTopLevelField(fm, "description"), `${file} missing description`);
    assert.ok(getTopLevelField(fm, "model"), `${file} missing model`);
    assert.ok(getTopLevelField(fm, "mode"), `${file} missing mode`);
  }
});

test("subagents are marked as mode: subagent", () => {
  for (const name of requiredSubagents) {
    const file = path.join(".opencode", "agents", `${name}.md`);
    const fm = getFrontmatter(fs.readFileSync(file, "utf8"));
    assert.equal(getTopLevelField(fm, "mode"), "subagent", `${name} must be subagent`);
  }
});

test("apply orchestrator task permissions allow only approved subagents", () => {
  const file = path.join(".opencode", "agents", "opsx-apply-orchestrator.md");
  const fm = getFrontmatter(fs.readFileSync(file, "utf8"));

  assert.match(fm, /permission:\n\s+task:/, "missing permission.task block");
  assert.match(fm, /"\*":\s*deny/, "missing default deny rule");
  assert.match(fm, /opsx-implementer:\s*allow/, "implementer should be allowed");
  assert.match(fm, /opsx-test-fixer:\s*allow/, "test-fixer should be allowed");
  assert.match(fm, /opsx-code-reviewer:\s*allow/, "code-reviewer should be allowed");
  assert.match(fm, /opsx-docs-refactor:\s*allow/, "docs-refactor should be allowed");
});

test("commands are defined once in .opencode/commands with orchestrator bindings", () => {
  assert.equal(fs.existsSync(path.join(".opencode", "command")), false, "legacy .opencode/command directory should not exist");

  for (const commandName of requiredCommands) {
    const file = path.join(".opencode", "commands", `${commandName}.md`);
    assert.ok(fs.existsSync(file), `missing command file ${file}`);

    const fm = getFrontmatter(fs.readFileSync(file, "utf8"));
    const agent = getTopLevelField(fm, "agent");
    const subtask = getTopLevelField(fm, "subtask");

    assert.ok(agent, `${file} missing frontmatter agent`);
    assert.equal(subtask, "true", `${file} should set subtask: true`);
  }

  const expected = {
    "opsx-explore": "opsx-explore-orchestrator",
    "opsx-propose": "opsx-propose-orchestrator",
    "opsx-apply": "opsx-apply-orchestrator",
    "opsx-archive": "opsx-archive-orchestrator"
  };

  for (const [commandName, expectedAgent] of Object.entries(expected)) {
    const file = path.join(".opencode", "commands", `${commandName}.md`);
    const fm = getFrontmatter(fs.readFileSync(file, "utf8"));
    assert.equal(getTopLevelField(fm, "agent"), expectedAgent);
  }
});
