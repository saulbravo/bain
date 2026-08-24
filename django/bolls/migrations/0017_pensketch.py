import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('bolls', '0016_versenotelink_broken'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='PenSketch',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('translation', models.CharField(max_length=120)),
                ('book', models.PositiveSmallIntegerField()),
                ('chapter', models.PositiveSmallIntegerField()),
                ('sketches', models.TextField()),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.AddIndex(
            model_name='pensketch',
            index=models.Index(fields=['user', 'translation', 'book', 'chapter'], name='bolls_pen_user_chapter_idx'),
        ),
        migrations.AddConstraint(
            model_name='pensketch',
            constraint=models.UniqueConstraint(fields=('user', 'translation', 'book', 'chapter'), name='uniq_user_chapter_pen_sketch'),
        ),
    ]
