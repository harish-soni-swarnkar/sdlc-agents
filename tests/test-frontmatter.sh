#!/usr/bin/env bash
# Strict-YAML check of every frontmatter block: agents, skills, rules templates, and the
# portable skills. Claude Code parses frontmatter leniently, but other tools and validators
# don't — an unquoted ": " inside a description is accepted by one and rejected by the
# other — so every file is held to the strict bar. Requires ruby (preinstalled on macOS
# with Homebrew and on GitHub's Ubuntu runners).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 ruby -Eutf-8:utf-8 -ryaml -e '
files = Dir["agents/*.md"] + Dir["skills/*/SKILL.md"] + Dir["templates/rules/*.md"] + Dir["portable/skills/*/SKILL.md"]
bad = 0
files.sort.each do |f|
  fm = File.read(f, encoding: "UTF-8")[/\A---\n(.*?)\n---\n/m, 1]
  begin
    raise "no frontmatter" unless fm
    h = YAML.safe_load(fm)
    raise "frontmatter is not a mapping" unless h.is_a?(Hash)
    if f.start_with?("agents/", "skills/", "portable/")
      %w[name description].each { |k| raise "missing or non-string #{k}" unless h[k].is_a?(String) }
    end
  rescue => e
    bad += 1
    puts "FAIL #{f}: #{e.message.lines.first.strip}"
  end
end
puts "frontmatter: #{files.size} files, #{bad} failing"
exit(bad.zero? ? 0 : 1)'
