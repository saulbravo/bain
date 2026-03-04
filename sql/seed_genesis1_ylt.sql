-- Minimal seed: Genesis 1 (YLT) so the app can load at least one chapter.
-- Run: docker exec -i database psql -U postgres_user -d postgres_db -f - < sql/seed_genesis1_ylt.sql
-- Or: cat sql/seed_genesis1_ylt.sql | docker exec -i database psql -U postgres_user -d postgres_db

INSERT INTO bolls_verses(translation, book, chapter, verse, text) VALUES
('YLT', 1, 1, 1, 'In the beginning of God''s preparing the heavens and the earth'),
('YLT', 1, 1, 2, 'the earth hath existed waste and void, and darkness [is] on the face of the deep, and the Spirit of God fluttering on the face of the waters,'),
('YLT', 1, 1, 3, 'and God saith, ``Let light be;'' and light is.'),
('YLT', 1, 1, 4, 'And God seeth the light that [it is] good, and God separateth between the light and the darkness,'),
('YLT', 1, 1, 5, 'and God calleth to the light ``Day,'' and to the darkness He hath called ``Night;'' and there is an evening, and there is a morning -- day one.'),
('YLT', 1, 1, 6, 'And God saith, ``Let an expanse be in the midst of the waters, and let it be separating between waters and waters.'''),
('YLT', 1, 1, 7, 'And God maketh the expanse, and it separateth between the waters which [are] under the expanse and the waters which [are] above the expanse: and it is so.'),
('YLT', 1, 1, 8, 'And God calleth to the expanse ``Heavens;'' and there is an evening, and there is a morning -- day second.'),
('YLT', 1, 1, 9, 'And God saith, ``Let the waters under the heavens be collected unto one place, and let the dry land be seen:'' and it is so.'),
('YLT', 1, 1, 10, 'And God calleth to the dry land ``Earth,'' and to the collection of the waters He hath called ``Seas;'' and God seeth that [it is] good.');
