export interface SubtitleCue {
  startTime: number;
  endTime: number;
  text: string;
}

function parseTimestamp(ts: string): number {
  const parts = ts.trim().replace(',', '.').split(':');
  if (parts.length === 3) {
    return parseFloat(parts[0]) * 3600 + parseFloat(parts[1]) * 60 + parseFloat(parts[2]);
  }
  if (parts.length === 2) {
    return parseFloat(parts[0]) * 60 + parseFloat(parts[1]);
  }
  return parseFloat(parts[0]) || 0;
}

export function parseSRT(content: string): SubtitleCue[] {
  const blocks = content.trim().replace(/\r\n/g, '\n').split(/\n\n+/);
  const cues: SubtitleCue[] = [];

  for (const block of blocks) {
    const lines = block.split('\n');
    const timeLineIdx = lines.findIndex(l => l.includes('-->'));
    if (timeLineIdx === -1) continue;

    const [startStr, endStr] = lines[timeLineIdx].split('-->');
    const text = lines.slice(timeLineIdx + 1).join('\n').replace(/<[^>]+>/g, '').trim();
    if (!text) continue;

    cues.push({
      startTime: parseTimestamp(startStr),
      endTime: parseTimestamp(endStr),
      text,
    });
  }
  return cues;
}

export function parseVTT(content: string): SubtitleCue[] {
  let cleaned = content.trim();
  if (cleaned.startsWith('WEBVTT')) {
    cleaned = cleaned.replace(/^WEBVTT.*?\n\n/s, '');
  }
  return parseSRT(cleaned);
}

export async function fetchAndParse(url: string): Promise<SubtitleCue[]> {
  try {
    const response = await fetch(url);
    const text = await response.text();
    if (url.endsWith('.vtt') || text.startsWith('WEBVTT')) {
      return parseVTT(text);
    }
    return parseSRT(text);
  } catch {
    return [];
  }
}
