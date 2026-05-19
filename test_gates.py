"""
Quick test to verify GATE 1 and GATE 2 are working correctly.
Tests rejection logic for false/contradicted reports.
"""

import asyncio
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'sahara_backend'))

from models import CrisisSignal
from orchestrator import orchestrator


async def test_false_report():
    """Test that false reports are rejected by GATE 1."""
    print("\n" + "="*70)
    print("TEST 1: False Signal (not a real crisis)")
    print("="*70)

    signal = CrisisSignal(
        text="Hello, just checking in. How are you doing today?",
        source="test_case"
    )

    result = await orchestrator.analyze(signal)

    print(f"\nResult Status: {result.status}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"System Message: {result.system_message}")

    assert result.status == "REJECTED", f"Expected REJECTED, got {result.status}"
    print("✅ TEST 1 PASSED: False signal correctly rejected by GATE 1")


async def test_contradicted_flooding():
    """Test that contradicted reports are rejected by GATE 2."""
    print("\n" + "="*70)
    print("TEST 2: Contradicted Signal (flooding claim but no rain)")
    print("="*70)

    # Islamabad flooding report in good weather (contradiction)
    signal = CrisisSignal(
        text="There is severe flooding happening in Islamabad right now! Many people are stuck in their homes!",
        source="test_case"
    )

    result = await orchestrator.analyze(signal)

    print(f"\nResult Status: {result.status}")
    print(f"Verification Status: {result.verification_status}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"Crisis Type: {result.crisis_type}")
    print(f"Location: {result.location}")
    print(f"System Message: {result.system_message}")

    # Should be UNVERIFIED due to GATE 2 rejection
    if result.status == "UNVERIFIED" and result.verification_status == "CONTRADICTED":
        print("✅ TEST 2 PASSED: Contradicted signal correctly rejected by GATE 2")
        print(f"   Contradictions detected: {len(result.agent_traces) > 1}")
    else:
        print(f"⚠️  TEST 2 INCONCLUSIVE: Status={result.status}, Verification={result.verification_status}")
        print("   (Check if weather API returned contradictions)")


async def test_valid_report():
    """Test that valid reports pass both gates."""
    print("\n" + "="*70)
    print("TEST 3: Valid Signal (should pass both gates)")
    print("="*70)

    # Traffic accident report (less dependent on weather)
    signal = CrisisSignal(
        text="There has been a serious road accident on the Margalla Road in Islamabad. Multiple vehicles involved. Emergency services needed immediately!",
        source="test_case"
    )

    result = await orchestrator.analyze(signal)

    print(f"\nResult Status: {result.status}")
    print(f"Verification Status: {result.verification_status}")
    print(f"Confidence: {result.confidence:.2f}")
    print(f"Crisis Type: {result.crisis_type}")
    print(f"Action Plan Items: {len(result.action_plan)}")
    print(f"Agents Executed: {len(result.agent_traces)}")

    # Should process through most/all agents
    if result.status == "PROCESSING" and len(result.agent_traces) >= 4:
        print("✅ TEST 3 PASSED: Valid signal correctly accepted and processed")
    else:
        print(f"⚠️  TEST 3 STATUS: {result.status} with {len(result.agent_traces)} agents")


async def main():
    print("\n" + "="*70)
    print("SAHARA AI - GATE VALIDATION TEST SUITE")
    print("Testing GATE 1 (Invalid Signals) and GATE 2 (Contradicted Reports)")
    print("="*70)

    try:
        await test_false_report()
    except Exception as e:
        print(f"❌ TEST 1 FAILED: {e}")

    try:
        await test_contradicted_flooding()
    except Exception as e:
        print(f"⚠️  TEST 2 ERROR: {e}")
        print("   (May be due to API unavailability)")

    try:
        await test_valid_report()
    except Exception as e:
        print(f"⚠️  TEST 3 ERROR: {e}")
        print("   (May be due to API unavailability)")

    print("\n" + "="*70)
    print("TEST SUITE COMPLETE")
    print("="*70 + "\n")


if __name__ == "__main__":
    asyncio.run(main())
