const mongoose = require("mongoose");

const sectionSchema = new mongoose.Schema(
  {
    title: String,
    content: String,
    timestamp: Date,
    lowConfidence: Boolean,
  },
  { _id: false }
);

const draftSchema = new mongoose.Schema(
  {
    id: { type: String, unique: true, index: true },
    reportNumber: String,
    status: { type: String, default: "draft" },
    language: String,
    complainantName: String,
    complainantPhone: String,
    complainantAddress: String,
    station: String,
    district: String,
    occurrenceDate: String,
    occurrenceTime: String,
    placeOfOccurrence: String,
    natureOfOffence: String,
    accusedDetails: String,
    rawTranscript: String,
    summary: String,
    confidenceScore: Number,
    sections: [sectionSchema],
    createdAt: Date,
    updatedAt: Date,
  },
  { timestamps: false }
);

module.exports = mongoose.models.Draft || mongoose.model("Draft", draftSchema);
