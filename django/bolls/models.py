from django.db import models
from django.contrib.auth.models import User


class Verses(models.Model):
    translation = models.CharField(max_length=120)
    book = models.PositiveSmallIntegerField()
    chapter = models.PositiveSmallIntegerField()
    verse = models.PositiveSmallIntegerField()
    text = models.TextField()

    def natural_key(self):
        return (self.translation, self.book, self.chapter, self.verse, self.text)

    class Meta:
        indexes = [
            models.Index(fields=['translation', 'book', 'chapter']),
            models.Index(fields=['translation', 'book', 'chapter', 'verse']),
        ]


class Commentary(models.Model):
    translation = models.CharField(max_length=120)
    book = models.PositiveSmallIntegerField()
    chapter = models.PositiveSmallIntegerField()
    verse = models.PositiveSmallIntegerField()
    text = models.TextField()

    class Meta:
        indexes = [
            models.Index(fields=['translation', 'book', 'chapter']),
            models.Index(fields=['translation', 'book', 'chapter', 'verse']),
        ]


class Note(models.Model):
    text = models.TextField()


class Bookmarks(models.Model):
    verse = models.ForeignKey(Verses, on_delete=models.CASCADE)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    date = models.BigIntegerField()
    color = models.CharField(max_length=32)
    collection = models.TextField(default=None)
    note = models.OneToOneField(Note, on_delete=models.CASCADE, null=True)


class History(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    history = models.TextField()
    purge_date = models.PositiveBigIntegerField(default=0)
    compare_translations = models.TextField(null=True, default=None)
    favorite_translations = models.TextField(null=True, default=None)


class FreehandHighlight(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    translation = models.CharField(max_length=120)
    book = models.PositiveSmallIntegerField()
    chapter = models.PositiveSmallIntegerField()
    # Storing ranges as JSON: [{"startVerse": 1, "startOffset": 0, "endVerse": 1, "endOffset": 10, "color": "#ff0000"}]
    highlights = models.TextField()

    class Meta:
        indexes = [
            models.Index(fields=['user', 'translation', 'book', 'chapter']),
        ]


class VerseNoteLink(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    block_id = models.CharField(max_length=64)
    translation = models.CharField(max_length=120)
    book = models.PositiveSmallIntegerField()
    chapter = models.PositiveSmallIntegerField()
    start_verse = models.PositiveSmallIntegerField()
    end_verse = models.PositiveSmallIntegerField()
    note_path = models.TextField()
    note_name = models.CharField(max_length=255, blank=True, default="")
    vault = models.CharField(max_length=255, blank=True, default="")
    date = models.BigIntegerField()
    broken = models.BooleanField(default=False)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "block_id"], name="uniq_user_verse_note_link"),
        ]
        indexes = [
            models.Index(fields=["user", "translation", "book", "chapter"], name="bolls_verse_user_id_note_idx"),
            models.Index(fields=["user", "block_id"], name="bolls_verse_user_block_idx"),
        ]


class Dictionary(models.Model):
    dictionary = models.CharField(max_length=8)
    topic = models.TextField()
    definition = models.TextField()
    lexeme = models.TextField()
    transliteration = models.TextField()
    pronunciation = models.TextField()
    short_definition = models.TextField(null=True)
