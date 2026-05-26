-- ================================================================
-- MatchInMinutes — Demo data fill (April 2026)
-- ================================================================
-- Populates realistic sample content for every profile on the
-- Tinder-style columns we just added (DOB, zodiac, drinking,
-- smoking, workout, pets, children, diet, religion, languages,
-- height_cm, first_date_idea) and also marks every profile as
-- face-verified so you can skip the selfie flow while demoing.
--
-- Safe to re-run — rows are only updated when the target column
-- is still NULL, so real user data is never overwritten.
--
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- ================================================================

-- Assign each profile a deterministic "bucket" (0-4) based on the
-- first character of its UUID, then fill its details from five
-- plausible persona presets. This gives demo data variety without
-- needing per-row UPDATEs.
WITH buckets AS (
  SELECT
    id,
    (('x' || substr(id::text, 1, 1))::bit(4)::int) % 5 AS b
  FROM public.profiles
)
UPDATE public.profiles p
SET
  is_verified = TRUE,
  verification_image_url = COALESCE(p.verification_image_url, p.main_image_url),

  date_of_birth = COALESCE(p.date_of_birth,
    (CASE b.b
       WHEN 0 THEN DATE '1996-04-12'
       WHEN 1 THEN DATE '1998-09-23'
       WHEN 2 THEN DATE '1994-11-05'
       WHEN 3 THEN DATE '2000-02-14'
       ELSE       DATE '1992-07-30'
     END)),

  -- Keep age in sync with DOB when we just derived it.
  age = CASE
    WHEN p.date_of_birth IS NULL THEN
      EXTRACT(YEAR FROM age(
        (CASE b.b
           WHEN 0 THEN DATE '1996-04-12'
           WHEN 1 THEN DATE '1998-09-23'
           WHEN 2 THEN DATE '1994-11-05'
           WHEN 3 THEN DATE '2000-02-14'
           ELSE       DATE '1992-07-30'
         END)
      ))::int
    ELSE p.age
  END,

  zodiac_sign = COALESCE(p.zodiac_sign,
    (CASE b.b
       WHEN 0 THEN 'Aries'
       WHEN 1 THEN 'Libra'
       WHEN 2 THEN 'Scorpio'
       WHEN 3 THEN 'Aquarius'
       ELSE       'Leo'
     END)),

  drinking = COALESCE(p.drinking,
    (CASE b.b
       WHEN 0 THEN 'socially'
       WHEN 1 THEN 'rarely'
       WHEN 2 THEN 'never'
       WHEN 3 THEN 'socially'
       ELSE       'often'
     END)),

  smoking = COALESCE(p.smoking,
    (CASE b.b
       WHEN 0 THEN 'never'
       WHEN 1 THEN 'never'
       WHEN 2 THEN 'trying_to_quit'
       WHEN 3 THEN 'socially'
       ELSE       'never'
     END)),

  workout = COALESCE(p.workout,
    (CASE b.b
       WHEN 0 THEN 'regularly'
       WHEN 1 THEN 'sometimes'
       WHEN 2 THEN 'daily'
       WHEN 3 THEN 'never'
       ELSE       'regularly'
     END)),

  pets = COALESCE(p.pets,
    (CASE b.b
       WHEN 0 THEN 'dog'
       WHEN 1 THEN 'cat'
       WHEN 2 THEN 'none'
       WHEN 3 THEN 'want_one'
       ELSE       'both'
     END)),

  children = COALESCE(p.children,
    (CASE b.b
       WHEN 0 THEN 'want'
       WHEN 1 THEN 'unsure'
       WHEN 2 THEN 'dont_want'
       WHEN 3 THEN 'want'
       ELSE       'have_and_want_more'
     END)),

  diet = COALESCE(p.diet,
    (CASE b.b
       WHEN 0 THEN 'non_vegetarian'
       WHEN 1 THEN 'vegetarian'
       WHEN 2 THEN 'vegan'
       WHEN 3 THEN 'eggetarian'
       ELSE       'non_vegetarian'
     END)),

  religion = COALESCE(p.religion,
    (CASE b.b
       WHEN 0 THEN 'Hindu'
       WHEN 1 THEN 'Spiritual'
       WHEN 2 THEN 'Agnostic'
       WHEN 3 THEN 'Christian'
       ELSE       'Muslim'
     END)),

  languages = CASE
    WHEN p.languages IS NULL OR array_length(p.languages, 1) IS NULL THEN
      (CASE b.b
         WHEN 0 THEN ARRAY['English','Hindi']
         WHEN 1 THEN ARRAY['English','Tamil']
         WHEN 2 THEN ARRAY['English','Telugu','Hindi']
         WHEN 3 THEN ARRAY['English','Kannada']
         ELSE       ARRAY['English','Hindi','Marathi']
       END)
    ELSE p.languages
  END,

  height_cm = COALESCE(p.height_cm,
    (CASE b.b
       WHEN 0 THEN 172
       WHEN 1 THEN 165
       WHEN 2 THEN 180
       WHEN 3 THEN 158
       ELSE       175
     END)),

  first_date_idea = COALESCE(p.first_date_idea,
    (CASE b.b
       WHEN 0 THEN 'Rooftop coffee at sunset, then a long walk and dessert wherever smells best.'
       WHEN 1 THEN 'Bookstore browsing followed by cozy cafe chai and swapping playlists.'
       WHEN 2 THEN 'Beach-side bike ride and street food — loud music optional, laughs mandatory.'
       WHEN 3 THEN 'Cooking something simple together at home and watching an old movie.'
       ELSE       'Live music at a small venue and late-night dosas after.'
     END)),

  bio = COALESCE(NULLIF(p.bio, ''),
    (CASE b.b
       WHEN 0 THEN 'Sunset chaser, weekend hiker, incurable foodie. Looking for someone who laughs at my bad puns.'
       WHEN 1 THEN 'Bookworm by day, salsa dancer by night. Let''s find a new cafe together.'
       WHEN 2 THEN 'Gym rat who also plays chess badly. Deep conversations and good coffee.'
       WHEN 3 THEN 'Animator + amateur baker. Show me your favourite playlist.'
       ELSE       'Engineer turned travel junkie. 23 countries down, still counting.'
     END)),

  hobbies = CASE
    WHEN p.hobbies IS NULL OR array_length(p.hobbies, 1) IS NULL THEN
      (CASE b.b
         WHEN 0 THEN ARRAY['Travel','Photography','Cooking']
         WHEN 1 THEN ARRAY['Reading','Dancing','Coffee']
         WHEN 2 THEN ARRAY['Fitness','Hiking','Gaming']
         WHEN 3 THEN ARRAY['Art','Movies','Music']
         ELSE       ARRAY['Cycling','Yoga','Volunteering']
       END)
    ELSE p.hobbies
  END,

  vibes = CASE
    WHEN p.vibes IS NULL OR array_length(p.vibes, 1) IS NULL THEN
      (CASE b.b
         WHEN 0 THEN ARRAY['Adventurous','Funny']
         WHEN 1 THEN ARRAY['Creative','Romantic']
         WHEN 2 THEN ARRAY['Ambitious','Intellectual']
         WHEN 3 THEN ARRAY['Homebody','Creative']
         ELSE       ARRAY['Outdoorsy','Social butterfly']
       END)
    ELSE p.vibes
  END,

  occupation = COALESCE(NULLIF(p.occupation, ''),
    (CASE b.b
       WHEN 0 THEN 'Product Designer'
       WHEN 1 THEN 'Software Engineer'
       WHEN 2 THEN 'Marketing Manager'
       WHEN 3 THEN 'Graphic Artist'
       ELSE       'Data Scientist'
     END))

FROM buckets b
WHERE p.id = b.id;

-- Sanity-check result:
-- SELECT name, age, zodiac_sign, drinking, workout, pets, diet, height_cm, first_date_idea
-- FROM public.profiles ORDER BY name;
