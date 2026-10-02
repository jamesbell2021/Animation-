#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "DTDTypes.h"
#include "DTDGameMode.generated.h"

class ADTDCommander;
class ADTDObjectiveZone;
class ADTDSharedCamera;
class ADTDSquadStart;

/**
 * Creates Player 2, gives each player a side, brings squads in at their Squad Starts,
 * sends reserves in waves, and checks who has won.
 */
UCLASS()
class DEFENDTHEDRIFT_API ADTDGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ADTDGameMode();

	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;
	/** Players never get a pawn: they drive commanders through the controller. */
	virtual void RestartPlayer(AController* NewPlayer) override;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD")
	TSubclassOf<ADTDCommander> BritishCommanderClass;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD")
	TSubclassOf<ADTDCommander> ZuluCommanderClass;

	/** Keyboard player's side. Player 2 gets the other. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD")
	EDTDFaction Player1Faction = EDTDFaction::British;

	/** Real seconds from 16:30 to 04:00. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (ClampMin = "1"))
	float MatchLengthSeconds = 720.f;

	/** Seconds between reserve waves. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (ClampMin = "1"))
	float WaveInterval = 25.f;

	/** Most men each squad gets per wave. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (ClampMin = "1"))
	int32 WaveSize = 10;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (ClampMin = "1"))
	int32 MaxZuluOnField = 90;

	/** Seconds the storehouse must be held by Zulu alone. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (ClampMin = "1"))
	float CaptureSeconds = 20.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD")
	bool bPauseOnMatchEnd = true;

	/** Commanders of one side that have arrived, in Squad Index order. */
	UFUNCTION(BlueprintPure, Category = "DTD")
	TArray<ADTDCommander*> GetCommanders(EDTDFaction Faction) const;

	UFUNCTION(BlueprintCallable, Category = "DTD")
	void EndMatch(EDTDFaction Winner, FText Reason);

	/** Show the end screen here. */
	UFUNCTION(BlueprintImplementableEvent, Category = "DTD")
	void OnMatchEnded(EDTDFaction Winner, const FText& Reason);

private:
	void SetUpPlayers();
	void SpawnArrivals();
	ADTDCommander* SpawnSquad(ADTDSquadStart* Start);
	void SpawnReserves();
	void UpdateCountsAndCheckWin(float DeltaSeconds);
	int32 CountLiveUnits(EDTDFaction Faction) const;

	UPROPERTY(Transient)
	TArray<TObjectPtr<ADTDSquadStart>> PendingStarts;

	UPROPERTY(Transient)
	TArray<TObjectPtr<ADTDCommander>> Commanders;

	UPROPERTY(Transient)
	TObjectPtr<ADTDObjectiveZone> Objective;

	UPROPERTY(Transient)
	TObjectPtr<ADTDSharedCamera> SharedCamera;

	float Elapsed = 0.f;
	float WaveTimer = 0.f;
	bool bMatchOver = false;
	bool bAnyBritishArrived = false;
	bool bAnyZuluSquads = false;
};
