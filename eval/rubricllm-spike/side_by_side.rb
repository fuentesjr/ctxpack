# frozen_string_literal: true
# Offline side-by-side for ctxpack issue #5: reproduce the committed
# packet-vs-diff coverage numbers with rubric_llm's RetrievalResult
# (pinned 02ceec3), and exercise its paired t-test on committed data.
# Reads ONLY committed artifacts; writes nothing to the repo.

require "json"
RUBRIC_LLM = ARGV[0] or abort "usage: ruby side_by_side.rb <path-to-rubric_llm-clone>  # pin commit 02ceec3"
$LOAD_PATH.unshift File.join(RUBRIC_LLM, "lib")
require "rubric_llm/retrieval_result"
require "rubric_llm/result"
require "rubric_llm/report"
require "rubric_llm/comparison"

sessions = JSON.parse(File.read("eval/tier2-expansion/coverage/coverage_by_session.json"))
mismatch = 0
compared = 0
sessions.each do |s|
  rr = RubricLLM::RetrievalResult.new(retrieved: s["packet_files"], relevant: s["diff_files"])
  k = s["packet_files"].size
  rec = k.zero? ? 0.0 : rr.recall_at_k(k)
  prec = k.zero? ? 0.0 : rr.precision_at_k(k)
  exp = s["all_files"]
  compared += 1
  unless (rec - exp["recall"]).abs < 1e-9 && (prec - exp["precision"]).abs < 1e-9
    mismatch += 1
    puts "MISMATCH #{s["session"]}: rubric r=#{rec} p=#{prec} vs recorded r=#{exp["recall"]} p=#{exp["precision"]}"
  end
end
puts "retrieval side-by-side: #{compared} sessions compared, #{mismatch} mismatches"

# Paired t-test exercise on committed per-session recall, paired
# control-vs-treatment by (app, task, round).
by_key = {}
sessions.each { |s| by_key[[s["app"], s["task"], s["round"], s["arm"]]] = s.dig("all_files", "recall") }
pairs = sessions.map { |s| [s["app"], s["task"], s["round"]] }.uniq.sort_by(&:to_s)
build = lambda do |arm|
  results = pairs.map do |app, task, round|
    v = by_key[[app, task, round, arm]]
    RubricLLM::Result.new(sample: { question: "#{app}-t#{task}-r#{round}", answer: arm },
                          scores: { "recall" => v }, details: {})
  end
  RubricLLM::Report.new(results: results)
end
cmp = RubricLLM::Comparison.new(build.call("control"), build.call("treatment"))
r = cmp.results["recall"]
puts "t-test over #{pairs.size} pairs: control=#{r[:mean_a].round(4)} treatment=#{r[:mean_b].round(4)} delta=#{r[:delta].round(4)} p=#{r[:p_value].round(6)}"

# n=3 landmines (documented hazards, synthetic):
mk = lambda do |vals, arm|
  RubricLLM::Report.new(results: vals.each_with_index.map { |v, i| RubricLLM::Result.new(sample: { question: "q#{i}", answer: arm }, scores: { "m" => v }, details: {}) })
end
uniform = RubricLLM::Comparison.new(mk.call([0.5, 0.5, 0.5], "a"), mk.call([0.6, 0.6, 0.6], "b")).results["m"]
puts "n=3 uniform +0.1 improvement: delta=#{uniform[:delta].round(3)} p=#{uniform[:p_value]} (se=0 hazard: perfect consistency reports NOT significant)"
noisy = RubricLLM::Comparison.new(mk.call([0.50, 0.52, 0.48], "a"), mk.call([0.70, 0.68, 0.75], "b")).results["m"]
puts "n=3 noisy +0.2 improvement: delta=#{noisy[:delta].round(3)} p=#{noisy[:p_value].round(6)} (stars would print with no n/df caveat)"
