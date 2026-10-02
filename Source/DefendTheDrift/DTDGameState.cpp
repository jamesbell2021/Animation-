#include "DTDGameState.h"

#define LOCTEXT_NAMESPACE "DTD"

float ADTDGameState::GetNightProgress() const
{
	return MatchLengthSeconds > 0.f ? FMath::Clamp(ElapsedSeconds / MatchLengthSeconds, 0.f, 1.f) : 1.f;
}

FText ADTDGameState::GetClockText() const
{
	const float Hours = FMath::Lerp(ClockStartHour, ClockEndHour, GetNightProgress());
	const int32 Minutes = FMath::FloorToInt(Hours * 60.f) % (24 * 60);
	return FText::FromString(FString::Printf(TEXT("%02d:%02d"), Minutes / 60, Minutes % 60));
}

FText ADTDGameState::GetFactionName(EDTDFaction Faction)
{
	return Faction == EDTDFaction::British
		? LOCTEXT("BritishGarrison", "British garrison")
		: LOCTEXT("ZuluArmy", "Zulu army");
}

#undef LOCTEXT_NAMESPACE
