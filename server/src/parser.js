// Rule-based extraction for English, Hindi and Marathi narrations.
// NOTE: lib/services/fir_parser.dart mirrors these rules so offline results match online ones.
// Keep the two in sync when editing.

// Devanagari-aware "word boundaries" (\b does not work for Devanagari in JS).
const NB = "(?<![\\u0900-\\u097F])";
const NA = "(?![\\u0900-\\u097F])";

function firstMatch(text, patterns) {
  for (const p of patterns) {
    const m = text.match(p);
    if (m) return (m[1] || m[0]).trim();
  }
  return "";
}

function extractName(text) {
  return firstMatch(text, [
    // The trigger phrase may be any case, but the captured name must be capitalised.
    /(?:[Mm]y name is|[Ii] am called|[Ii]'m called|[Tt]his is|[Ii] am|[Ii]'m)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})/,
    /(?:[Cc]omplainant|[Ii]nformant)\s+(?:is|:)\s+([A-Z][A-Za-z]*(?:\s+[A-Z][A-Za-z]*){0,3})/,
    /मेरा नाम\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,2}?)(?:\s+(?:है|हैं)|[,।.]|$)/,
    /माझे नाव\s+([^\s,।.]{2,}(?:\s+[^\s,।.]{2,}){0,2}?)(?:\s+आहे|[,।.]|$)/,
  ]);
}

function extractDate(text) {
  return firstMatch(text, [
    /\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b/,
    /\b(\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})\b/i,
    /\b(yesterday|today|last night|this morning)\b/i,
    new RegExp(NB + "(आज सुबह|गत रात|परसों|आज|कल|काल)" + NA),
  ]);
}

function extractTime(text) {
  return firstMatch(text, [
    /\b(\d{1,2}(?::\d{2})?\s*(?:a\.m\.|p\.m\.|am|pm))(?![a-z])/i,
    /\b(?:at|around|about)\s+(\d{1,2}:\d{2})\b/i,
    /\b(\d{1,2}:\d{2})\b/,
    /\b(\d{1,2})\s*o'?\s*clock\b/i,
    // Hindi "11 बजे", Marathi "9 वाजता" / "9 वाजले"
    /(\d{1,2}(?::\d{2})?\s*(?:बजे|वाजता|वाजले))/,
    new RegExp("(सुबह|शाम|रात|दोपहर|सकाळी|संध्याकाळी|रात्री|दुपारी)" + NA + "\\s*(?:\\d{1,2}(?:[:.]\\d{2})?)?"),
  ]);
}

const TIME_WORDS = new Set(["आज", "कल", "काल", "परसों", "गत", "रात", "सुबह", "शाम", "दोपहर", "सकाळी", "संध्याकाळी", "रात्री", "दुपारी", "बजे", "वाजता", "वाजले", "लगभग", "करीब", "सुमारे"]);

// Drop leading date/time words that the postposition pattern may have swept up.
function stripTimeWords(place) {
  const words = place.split(/\s+/);
  while (words.length > 1 && (TIME_WORDS.has(words[0]) || /^\d/.test(words[0]))) words.shift();
  return words.join(" ").replace(/[.,;]+$/, "");
}

function extractLocation(text) {
  return stripTimeWords(firstMatch(text, [
    // A place is a run of capitalised words after a preposition ("near City Mall", "at Gandhi Nagar").
    // Months and weekdays are excluded so "in March" is not read as a place.
    /\b(?:[Aa]t|[Ii]n|[Nn]ear|[Oo]utside|[Ii]nside|[Oo]pposite|[Bb]ehind)\s+(?!(?:January|February|March|April|May|June|July|August|September|October|November|December|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\b)((?:[A-Z][\w.'-]*)(?:\s+(?:of\s+)?[A-Z][\w.'-]*){0,5})/,
    /(?:स्थान|जगह|पते|पता)\s*[:-]?\s*([^\n।.]{3,60})/,
    // Postpositions follow the place: "<place> में / पर / के पास / येथे / जवळ".
    new RegExp("([^\\s।,.]+(?:\\s+[^\\s।,.]+){0,3})\\s+(?:में|पर|के पास|येथे|इथे|जवळ)" + NA),
    /पत्त्यावर\s*[:-]?\s*([^\n।.]{3,60})/,
  ]));
}

const OFFENCES = {
  "Theft / चोरी": ["theft", "stolen", "stole", "steal", "burglary", "broke into", "break in", "chori", "चोरी", "चोरीला", "चोरले"],
  "Robbery / डकैती": ["robbery", "looted", "snatched", "डकैती", "लूट", "लुटले"],
  "Assault / मारपीट": ["assault", "beaten", "hit me", "attacked", "मारपीट", "मारहाण", "मारहाई", "मारले", "पीटा"],
  "Cheating / ठगी": ["cheating", "fraud", "scam", "duped", "ठगी", "फसवणूक", "धोखा"],
  "Harassment / छेड़छाड़": ["harassment", "eve teasing", "stalking", "छेड़छाड़", "छेडछाड", "छळ"],
  "Accident / अपघात": ["accident", "collision", "अपघात", "दुर्घटना"],
  "Missing person / गुमशुदगी": ["लापता", "बेपत्ता", "गुमशुदा"],
  "Criminal intimidation / धमकी": ["threat", "threatened", "धमकी", "धमकवले"],
};

function hasKeyword(text, lower, k) {
  if (/^[a-z ]+$/i.test(k)) {
    return new RegExp("\\b" + k.replace(/ /g, "\\s+"), "i").test(lower);
  }
  return text.includes(k);
}

function extractOffence(text) {
  const lower = text.toLowerCase();
  let best = null;
  let bestScore = 0;
  for (const [label, keys] of Object.entries(OFFENCES)) {
    let score = keys.filter((k) => hasKeyword(text, lower, k)).length;
    // "missing" means a missing person only when a person is the subject ("my phone is missing" is not).
    if (
      label.startsWith("Missing") &&
      /\bmissing\b/i.test(text) &&
      /\b(son|daughter|child|wife|husband|brother|sister|boy|girl|person|father|mother)\b/i.test(text)
    ) {
      score += 1;
    }
    if (score > bestScore) {
      best = label;
      bestScore = score;
    }
  }
  return best || "Cognisable offence as narrated (to be classified by duty officer)";
}

function extractAccused(text) {
  const named = firstMatch(text, [
    /(?:[Aa]ccused|[Ss]uspect)(?:\s+(?:is|was|named))?\s*:?\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})/,
    /(?:by a (?:man|woman|person) named|[Nn]amed)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3})/,
    /(?:आरोपी|संदिग्ध|संशयित|नाम है)\s*[:-]?\s*([^\n।.]{2,40})/,
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
  const text = String(transcript || "").trim();
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
