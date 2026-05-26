class CompatibilityQuestion {
  final String id;
  final String question;
  final List<String> options;
  const CompatibilityQuestion({
    required this.id,
    required this.question,
    required this.options,
  });
}

// Long-term relationship & Marriage questions
const _longTermQuestions = [
  CompatibilityQuestion(
    id: 'lt_commitment',
    question: 'How do you approach commitment?',
    options: [
      'I take time, then commit fully',
      'I know pretty quickly',
      'I let it grow naturally',
    ],
  ),
  CompatibilityQuestion(
    id: 'lt_kids',
    question: 'How do you feel about having kids?',
    options: ['I want kids', "I don't want kids", "I'm unsure", 'I already have kids'],
  ),
  CompatibilityQuestion(
    id: 'lt_marriage',
    question: "What's your view on marriage?",
    options: ['Fully open to it', 'Open but flexible', 'Not for me'],
  ),
  CompatibilityQuestion(
    id: 'lt_5years',
    question: 'Where do you see yourself in 5 years?',
    options: ['Settled down', 'Career focused', 'Still exploring', 'Not sure'],
  ),
  CompatibilityQuestion(
    id: 'lt_conflict',
    question: 'How do you handle conflict?',
    options: ['Talk it out immediately', 'Need space first', 'Calm and direct'],
  ),
  CompatibilityQuestion(
    id: 'lt_lovelang',
    question: "What's your love language?",
    options: ['Quality time', 'Physical touch', 'Words of affirmation', 'Acts of service'],
  ),
  CompatibilityQuestion(
    id: 'lt_living',
    question: 'Living together — when?',
    options: ['After marriage', 'Before marriage to test', 'Open to either'],
  ),
  CompatibilityQuestion(
    id: 'lt_finances',
    question: 'How do you handle finances as a couple?',
    options: ['Combine everything', 'Keep it separate', 'Figure it out together'],
  ),
  CompatibilityQuestion(
    id: 'lt_settle',
    question: 'How soon do you want to settle down?',
    options: ['Within a year', '1–3 years', 'No rush'],
  ),
  CompatibilityQuestion(
    id: 'lt_religion',
    question: 'Religion in a relationship?',
    options: ['Very important — must match', 'Somewhat important', "Doesn't matter to me"],
  ),
];

// Short-term & Casual questions
const _shortTermQuestions = [
  CompatibilityQuestion(
    id: 'st_looking',
    question: 'What are you looking for right now?',
    options: ['Fun & adventure', 'Meaningful connection', 'Both'],
  ),
  CompatibilityQuestion(
    id: 'st_start',
    question: 'How do you start a connection?',
    options: ['Jump right in', 'Take it slow', 'Go with the flow'],
  ),
  CompatibilityQuestion(
    id: 'st_exclusive',
    question: 'Exclusivity?',
    options: ['Open to it if it feels right', 'Not looking for it', 'Prefer to keep it open'],
  ),
  CompatibilityQuestion(
    id: 'st_weekend',
    question: 'Your weekend vibe?',
    options: ['Outdoor adventures', 'Cozy nights in', 'Social scenes', 'Spontaneous'],
  ),
  CompatibilityQuestion(
    id: 'st_comms',
    question: 'Communication style?',
    options: ['Text all day', 'Check in occasionally', 'Voice calls', 'Quality over quantity'],
  ),
  CompatibilityQuestion(
    id: 'st_firstdate',
    question: 'First date idea?',
    options: ['Dinner out', 'Coffee & walk', 'Adventure activity', 'Chill at home'],
  ),
  CompatibilityQuestion(
    id: 'st_care',
    question: 'How do you show you care?',
    options: ['Compliments', 'Quality time', 'Small gestures', 'Physical affection'],
  ),
  CompatibilityQuestion(
    id: 'st_friends',
    question: 'Meeting friends — when?',
    options: ['Early on', 'After some time', 'Keep it separate for now'],
  ),
  CompatibilityQuestion(
    id: 'st_social',
    question: 'Your social life?',
    options: ['Very social', 'Balanced', 'Mostly private'],
  ),
  CompatibilityQuestion(
    id: 'st_greenflag',
    question: 'Biggest green flag?',
    options: ['Good listener', 'Makes me laugh', 'Ambitious', 'Emotionally available'],
  ),
];

// Friendship questions
const _friendshipQuestions = [
  CompatibilityQuestion(
    id: 'fr_make',
    question: 'How do you make new friends?',
    options: ['Easily — I talk to everyone', 'Takes time', 'Through shared interests'],
  ),
  CompatibilityQuestion(
    id: 'fr_value',
    question: 'What do you value most?',
    options: ['Loyalty', 'Humor', 'Deep conversations', 'Shared hobbies'],
  ),
  CompatibilityQuestion(
    id: 'fr_circle',
    question: 'Your friend circle?',
    options: ['Big and social', 'Small and close', 'One-on-one connections'],
  ),
  CompatibilityQuestion(
    id: 'fr_openup',
    question: 'How long to open up?',
    options: ['Pretty quickly', 'Takes some time', 'Takes a while'],
  ),
  CompatibilityQuestion(
    id: 'fr_hangout',
    question: 'Ideal hangout?',
    options: ['Group outings', 'One-on-one', 'Online / gaming', 'Mix of all'],
  ),
  CompatibilityQuestion(
    id: 'fr_care',
    question: 'How do you show you care?',
    options: ['Regular check-ins', 'Acts of kindness', 'Just being there', 'Listening'],
  ),
  CompatibilityQuestion(
    id: 'fr_conflict',
    question: 'Conflict in friendship?',
    options: ['Talk it out directly', 'Give it time', 'Open communication'],
  ),
  CompatibilityQuestion(
    id: 'fr_intro',
    question: 'Are you?',
    options: ['Introvert', 'Extrovert', 'Ambivert'],
  ),
  CompatibilityQuestion(
    id: 'fr_bring',
    question: 'You bring to a friendship:',
    options: ['Loyalty', 'Fun energy', 'Emotional support', 'Adventures'],
  ),
  CompatibilityQuestion(
    id: 'fr_socialize',
    question: 'Your love for socializing?',
    options: ['Always up for plans', 'Need notice first', 'Homebody mostly'],
  ),
];

/// Returns the 10 questions for the given relationship_goal backend value.
/// Falls back to long-term questions for unknown/unsure goals.
List<CompatibilityQuestion> questionsForGoal(String? goal) {
  switch (goal) {
    case 'long_term':
    case 'marriage':
    case 'unsure':
      return _longTermQuestions;
    case 'short_term':
    case 'casual':
      return _shortTermQuestions;
    case 'friendship':
      return _friendshipQuestions;
    default:
      return _longTermQuestions;
  }
}

/// Section title shown above the cards based on goal.
String compatibilitySectionTitle(String? goal) {
  switch (goal) {
    case 'long_term':
    case 'marriage':
      return 'Long term compatibility';
    case 'short_term':
    case 'casual':
      return 'Connection style';
    case 'friendship':
      return 'Friendship compatibility';
    default:
      return 'Compatibility';
  }
}
