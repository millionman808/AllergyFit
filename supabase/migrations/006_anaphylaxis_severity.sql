-- Add an "anaphylaxis" tier above "severe" so users can mark life-threatening
-- allergens (e.g. nuts) distinctly from mild sensitivities (e.g. a little gluten).
-- ADD VALUE can't run inside a transaction block, so this migration must be run
-- on its own (Supabase dashboard SQL editor runs it fine).
alter type severity_level add value if not exists 'anaphylaxis' after 'severe';
