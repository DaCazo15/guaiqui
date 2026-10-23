import { describe, it, expect } from 'vitest'

function calculateVideoPointsAwarded(completedCount: number): number {
  // Puntos se otorgan ÚNICAMENTE cada 10 videos completados
  if (completedCount <= 0 || completedCount > 50 || completedCount % 10 !== 0) {
    return 0
  }

  const blockNumber = completedCount / 10
  if (blockNumber === 1) return 5
  if (blockNumber === 2) return 10
  return 15 // Bloques 3, 4 y 5
}

function calculateNextTierReward(completedCount: number): number {
  const currentBlock = Math.floor(completedCount / 10) + 1
  if (currentBlock === 1) return 5
  if (currentBlock === 2) return 10
  return 15
}

function canWatchVideoToday(viewsToday: number, dailyLimit = 50): boolean {
  return viewsToday < dailyLimit
}

function getRandomVideo<T>(videos: T[]): T | null {
  if (videos.length === 0) return null
  const index = Math.floor(Math.random() * videos.length)
  return videos[index]
}

describe('Sponsored Videos Block Rewards (10 videos per block, max 60 pts/day)', () => {
  it('awards 0 points for individual video views between blocks', () => {
    // Videos 1 al 9 no dan puntos
    for (let count = 1; count < 10; count++) {
      expect(calculateVideoPointsAwarded(count)).toBe(0)
    }
    // Videos 11 al 19 no dan puntos
    for (let count = 11; count < 20; count++) {
      expect(calculateVideoPointsAwarded(count)).toBe(0)
    }
    // Videos 21 al 29 no dan puntos
    for (let count = 21; count < 30; count++) {
      expect(calculateVideoPointsAwarded(count)).toBe(0)
    }
  })

  it('awards points only on milestone block completions', () => {
    expect(calculateVideoPointsAwarded(10)).toBe(5) // Bloque 1
    expect(calculateVideoPointsAwarded(20)).toBe(10) // Bloque 2
    expect(calculateVideoPointsAwarded(30)).toBe(15) // Bloque 3
    expect(calculateVideoPointsAwarded(40)).toBe(15) // Bloque 4
    expect(calculateVideoPointsAwarded(50)).toBe(15) // Bloque 5
  })

  it('accumulates exactly 60 points when watching all 50 videos', () => {
    let totalPoints = 0
    for (let count = 1; count <= 50; count++) {
      totalPoints += calculateVideoPointsAwarded(count)
    }
    expect(totalPoints).toBe(60)
  })

  it('calculates the next tier reward correctly based on current count', () => {
    expect(calculateNextTierReward(0)).toBe(5) // En bloque 1
    expect(calculateNextTierReward(9)).toBe(5) // A punto de completar bloque 1
    expect(calculateNextTierReward(10)).toBe(10) // En bloque 2
    expect(calculateNextTierReward(19)).toBe(10) // A punto de completar bloque 2
    expect(calculateNextTierReward(20)).toBe(15) // En bloque 3
    expect(calculateNextTierReward(35)).toBe(15) // En bloque 4
    expect(calculateNextTierReward(45)).toBe(15) // En bloque 5
  })

  it('enforces maximum 50 videos limit per day', () => {
    expect(canWatchVideoToday(0)).toBe(true)
    expect(canWatchVideoToday(49)).toBe(true)
    expect(canWatchVideoToday(50)).toBe(false)
    expect(canWatchVideoToday(51)).toBe(false)
  })

  it('picks a random video from available list', () => {
    const list = [
      { id: '1', title: 'Video A' },
      { id: '2', title: 'Video B' },
      { id: '3', title: 'Video C' },
    ]
    const chosen = getRandomVideo(list)
    expect(chosen).not.toBeNull()
    expect(list.some((v) => v.id === chosen?.id)).toBe(true)
  })

  it('handles empty video list gracefully', () => {
    expect(getRandomVideo([])).toBeNull()
  })
})
