const test = require("node:test");
const assert = require("node:assert/strict");
const { parseTranscript } = require("../src/parser");

const cases = [
  {
    name: "English burglary at night",
    text: "My name is Sunita Deshmukh. Last night around 11 pm someone broke into my house at Gandhi Nagar and stole gold jewellery.",
    expect: { complainantName: "Sunita Deshmukh", occurrenceDate: "Last night", occurrenceTime: "11 pm", placeOfOccurrence: "Gandhi Nagar", natureOfOffence: /^Theft/ },
  },
  {
    name: "English snatching with named accused",
    text: "I am Rahul Sharma. Two men on a bike snatched my phone near City Mall yesterday at 8:15 pm. The accused is Vikas Patil.",
    expect: { complainantName: "Rahul Sharma", occurrenceDate: "yesterday", occurrenceTime: "8:15 pm", placeOfOccurrence: "City Mall", natureOfOffence: /^Robbery/, accusedDetails: "Vikas Patil" },
  },
  {
    name: "English assault with long date",
    text: "My name is Priya Nair. On 12 March 2026 I was beaten by my neighbour outside Shivaji Park at 6 pm.",
    expect: { complainantName: "Priya Nair", occurrenceDate: "12 March 2026", occurrenceTime: "6 pm", placeOfOccurrence: "Shivaji Park", natureOfOffence: /^Assault/ },
  },
  {
    name: "Amounts are not times",
    text: "I am Mohan Das. I was cheated of 50000 rupees in an online fraud on 05/11/2026.",
    expect: { complainantName: "Mohan Das", occurrenceDate: "05/11/2026", occurrenceTime: "", natureOfOffence: /^Cheating/ },
  },
  {
    name: "Month is not a place",
    text: "My phone was stolen in March at Nashik Road Station.",
    expect: { placeOfOccurrence: "Nashik Road Station", natureOfOffence: /^Theft/ },
  },
  {
    name: "Not a name: ordinary sentence",
    text: "I am going to the market and my bag was stolen.",
    expect: { complainantName: "" },
  },
  {
    name: "Lost phone is not a missing person",
    text: "My phone is missing since morning.",
    expect: { natureOfOffence: /^Cognisable/ },
  },
  {
    name: "Missing person",
    text: "My son is missing since yesterday evening.",
    expect: { natureOfOffence: /^Missing/ },
  },
  {
    name: "Unknown accused and threat",
    text: "Unknown persons threatened me outside my shop.",
    expect: { natureOfOffence: /^Criminal intimidation/, accusedDetails: /^Unknown/ },
  },
  {
    name: "Stalking",
    text: "I am Neha Kulkarni. A man was stalking me near Pune Station since last week.",
    expect: { complainantName: "Neha Kulkarni", placeOfOccurrence: "Pune Station", natureOfOffence: /^Harassment/ },
  },
  {
    name: "Hindi burglary",
    text: "मेरा नाम सुनील पाटिल है। कल रात लगभग 11 बजे मेरे घर में चोरी हुई।",
    expect: { complainantName: "सुनील पाटिल", occurrenceDate: "कल", occurrenceTime: "11 बजे", placeOfOccurrence: "मेरे घर", natureOfOffence: /^Theft/ },
  },
  {
    name: "Marathi accident",
    text: "माझे नाव अमित पाटील आहे. काल सकाळी 9 वाजता नाशिक येथे अपघात झाला.",
    expect: { complainantName: "अमित पाटील", occurrenceDate: "काल", occurrenceTime: "9 वाजता", placeOfOccurrence: "नाशिक", natureOfOffence: /^Accident/ },
  },
  {
    name: "Empty narration",
    text: "   ",
    expect: { complainantName: "", natureOfOffence: "", summary: "" },
  },
];

for (const c of cases) {
  test(c.name, () => {
    const got = parseTranscript(c.text);
    for (const [field, want] of Object.entries(c.expect)) {
      if (want instanceof RegExp) assert.match(got[field], want, field);
      else assert.equal(got[field], want, field);
    }
  });
}
