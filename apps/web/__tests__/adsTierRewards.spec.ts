import { describe, it, expect } from 'vitest'

function calculateVideoTierReward(viewsToday: number): number {
  if (viewsToday < 10) return 5
  if (viewsToday < 20) return 10
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

describe('Sponsored Videos Tier Rewards and Limits', () => {
  it('awards 5 points for the first 10 videos (indices 0 to 9)', () => {
    for (let count = 0; count < 10; count++) {
      expect(calculateVideoTierReward(count)).toBe(5)
    }
  })

  it('awards 10 points for the next 10 videos (indices 10 to 19)', () => {
    for (let count = 10; count < 20; count++) {
      expect(calculateVideoTierReward(count)).toBe(10)
    }
  })

  it('awards 15 points from video 21 up to 50 (indices 20 to 49)', () => {
    expect(calculateVideoTierReward(20)).toBe(15)
    expect(calculateVideoTierReward(25)).toBe(15)
    expect(calculateVideoTierReward(49)).toBe(15)
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
