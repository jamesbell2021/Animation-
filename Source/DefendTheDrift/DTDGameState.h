#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameStateBase.h"
#include "DTDTypes.h"
#include "DTDGameState.generated.h"

/** What the HUD and end screen read. The game mode writes it every frame. */
UCLASS()
class DEFENDTHEDRIFT_API ADTDGameState : public AGameStateBase
{
	GENERATED_BODY()

public:
	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	float MatchLengthSeconds = 720.f;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	float ElapsedSeconds = 0.f;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	float TimeRemaining = 720.f;

	/** 0..1: how close the Zulu are to taking the storehouse. */
	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	float CaptureProgress = 0.f;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	int32 BritishStanding = 0;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	int32 ZuluOnField = 0;

	/** Reserves plus squads that haven't arrived yet. */
	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	int32 ZuluToCome = 0;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	bool bMatchOver = false;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	EDTDFaction Winner = EDTDFaction::British;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	FText WinReason;

	/** Clock shown at the start and end of the match, in hours. 28 = 04:00 the next morning. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD")
	float ClockStartHour = 16.5f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD")
	float ClockEndHour = 28.f;

	/** 0 at the start of the match, 1 at dawn. Drive lighting from this later. */
	UFUNCTION(BlueprintPure, Category = "DTD")
	float GetNightProgress() const;

	/** "16:30" .. "04:00". */
	UFUNCTION(BlueprintPure, Category = "DTD")
	FText GetClockText() const;

	/** "British garrison" or "Zulu army". */
	UFUNCTION(BlueprintPure, Category = "DTD")
	static FText GetFactionName(EDTDFaction Faction);
};
