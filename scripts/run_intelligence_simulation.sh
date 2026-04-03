#!/usr/bin/env bash
set -euo pipefail

tmp_bin="$(mktemp -t intelligence-sim.XXXXXX)"
trap 'rm -f "$tmp_bin"' EXIT

swiftc \
  "ND Planner App/Time Anchor/Models/PlanMode.swift" \
  "ND Planner App/Time Anchor/Models/DayAssessment.swift" \
  "ND Planner App/Time Anchor/Models/Task.swift" \
  "ND Planner App/Time Anchor/Models/Anchor.swift" \
  "ND Planner App/Time Anchor/Models/DailyState.swift" \
  "ND Planner App/Time Anchor/Models/PlanVersion.swift" \
  "ND Planner App/Time Anchor/Models/AdaptiveIntelligence.swift" \
  "ND Planner App/Time Anchor/Services/IntelligenceServices.swift" \
  "scripts/intelligence_simulation.swift" \
  -o "$tmp_bin"

"$tmp_bin"
