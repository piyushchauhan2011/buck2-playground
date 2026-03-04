export function formatVersion(
  major: number,
  minor: number,
  patch: number,
): string {
  return `${major}.${minor}.${patch}`;
}

export function formatTimestamp(date: Date = new Date()): string {
  return date.toISOString();
}
