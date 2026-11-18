function firstMatch(text, patterns) {
  for (const p of patterns) {
    const m = text.match(p);
    if (m) return (m[1] || m[0]).trim();
  }
  return "";
}

function extractName(text) {
  return firstMatch(text, [
    /(?:my name is|i am|i'm|this is)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})/i,
    /(?:complainant|informant)\s+(?:is|:)\s+([A-Za-z][A-Za-z\s]{1,40})/i,
    /मेरा नाम\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,3})/,
    /मैं\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,2})\s+(?:हूँ|हूं|है)/,
    /माझे नाव\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,3})/,
    /मी\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,2})\s+(?:आहे|आहो)/,
  ]);
}

function extractDate(text) {
  return firstMatch(text, [
    /\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b/,
    /\b(\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})\b/i,
    /\b(yesterday|today|last night|this morning)\b/i,
    /(आज|कल|काल|परसों|गत रात|आज सुबह)/,
  ]);
}

function extractTime(text) {
  return firstMatch(text, [
    /\b((?:at\s+)?\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?)\b/i,
    /(सुबह|शाम|रात|दोपहर|सकाळी|संध्याकाळी|रात्री|दुपारी)\s*(?:\d{1,2}(?:[:.]\d{2})?)?/,
    /(?:at around|around|about)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)/i,
  ]);
}

function extractLocation(text) {
  return firstMatch(text, [
    /(?:at|in|near|outside|inside)\s+([A-Z][A-Za-z0-9 ,.-]{2,60}?)(?=[.,;]|$)/,
    /(?:स्थान|जगह|पते|पता|में|पर)\s*[:\-]?\s*([^\n।.]{3,60})/,
    /(?:येथे|इथे|जवळ|गावात|पत्त्यावर)\s*[:\-]?\s*([^\n।.]{3,60})/,
  ]);
}

function extractOffence(text) {
  const lower = text.toLowerCase();
  const map = {
    "Theft / चोरी": ["theft", "stolen", "steal", "chori", "चोरी", "चोरले"],
    "Robbery / डकैती": ["robbery", "looted", "snatched", "डकैती", "लूट", "लुटले"],
    "Assault / मारपीट": ["assault", "beaten", "hit me", "attacked", "मारपीट", "मारहाई", "मारले"],
    "Cheating / ठगी": ["cheating", "fraud", "scam", "duped", "ठगी", "फसवणूक", "धोखा"],
    "Harassment / छेड़छाड़": ["harassment", "eve teasing", "stalking", "छेड़छाड़", "छेडछाड", "छळ"],
    "Accident / अपघात": ["accident", "collision", "अपघात", "दुर्घटना"],
    "Missing person / गुमशुदगी": ["missing", "गुम", "लापता"],
    "Criminal intimidation / धमकी": ["threat", "threatened", "धमकी", "धमकवले"],
  };
  for (const [label, keys] of Object.entries(map)) {
    if (keys.some((k) => lower.includes(k.toLowerCase()) || text.includes(k))) {
      return label;
    }
  }
  return "Cognisable offence as narrated (to be classified by duty officer)";
}

function extractAccused(text) {
  const named = firstMatch(text, [
    /(?:accused|suspect|by a (?:man|woman|person) named|named)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})/i,
    /(?:आरोपी|संदिग्ध|नाम है)\s*[:\-]?\s*([^\n।.]{2,40})/,
    /(?:आरोपी|संशयित)\s*[:\-]?\s*([^\n।.]{2,40})/,
  ]);
  if (named) return named;
  if (/\bunknown\b|अज्ञात|माहित नाही/i.test(text)) {
    return "Unknown / not identified by complainant";
  }
  return "";
}

function summarise(text) {
  const words = text.trim().split(/\s+/);
  if (words.length <= 28) return text;
  return `${words.slice(0, 28).join(" ")}…`;
}

function parseTranscript(transcript) {
  const text = (transcript || "").trim();
  if (!text) {
    return {
      complainantName: "",
      occurrenceDate: "",
      occurrenceTime: "",
      placeOfOccurrence: "",
      natureOfOffence: "",
      accusedDetails: "",
      incidentDescription: "",
      summary: "",
    };
  }
  return {
    complainantName: extractName(text),
    occurrenceDate: extractDate(text),
    occurrenceTime: extractTime(text),
    placeOfOccurrence: extractLocation(text),
    natureOfOffence: extractOffence(text),
    accusedDetails: extractAccused(text),
    incidentDescription: text,
    summary: summarise(text),
  };
}

module.exports = { parseTranscript };
