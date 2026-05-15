"""Quick end-to-end pipeline test for SAHARA AI backend."""
import sys, asyncio
sys.path.insert(0, '.')
from models import CrisisSignal
from orchestrator import AntigravityOrchestrator


async def test():
    orch = AntigravityOrchestrator()
    # Test Scenario 1: Islamabad Flooding
    sig = CrisisSignal(
        text="G-10 mein pani bhar gaya hai, gaariyan phans gayi hain",
        source="citizen_report",
        location_hint="G-10, Islamabad",
    )
    r = await orch.analyze(sig)
    print("\n" + "="*50)
    print("PIPELINE TEST RESULTS")
    print("="*50)
    print(f"Crisis ID:     {r.crisis_id}")
    print(f"Type:          {r.crisis_type}")
    print(f"Location:      {r.location}")
    print(f"Severity:      {r.severity}")
    print(f"Confidence:    {r.confidence:.0%}")
    print(f"Agents run:    {len(r.agent_traces)}")
    print(f"Actions:       {len(r.action_plan)}")
    print(f"Total time:    {r.total_execution_time_ms}ms")
    if r.simulation:
        s = r.simulation
        print(f"Congestion:    {s.congestion_level_before} -> {s.congestion_level_after}")
        print(f"Pop helped:    {s.population_helped:,}")
        print(f"Alerts sent:   {s.alerts_sent:,}")
        print(f"Units disp.:   {s.emergency_units_dispatched}")
        print(f"Tickets:       {len(s.emergency_tickets)}")
    print(f"Fallbacks:     {len(r.fallback_history)}")
    print("\nAgent traces:")
    for t in r.agent_traces:
        print(f"  [{t.agent_index}] {t.agent_name} — {t.confidence:.0%} confidence, {t.execution_time_ms}ms {'⚡ FALLBACK' if t.fallback_triggered else ''}")
    print("\n✅ TEST PASSED — Full Antigravity pipeline completed successfully")


asyncio.run(test())
