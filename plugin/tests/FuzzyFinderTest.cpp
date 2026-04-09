// FuzzyFinderTest — unit tests for the fuzzy file finder model.
//
// Creates directory trees programmatically in QTemporaryDir. Tests cover async
// scanning, Smith-Waterman scoring, gitignore parsing, generation counters,
// and the result cap. Uses QTEST_MAIN (not GUILESS) because
// QAbstractItemModelTester requires QGuiApplication.

#include "fuzzyfinder.hpp"

#include <QAbstractItemModelTester>
#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

using namespace symmetria::filemanager::models;

class FuzzyFinderTest : public QObject {
    Q_OBJECT

private:
    // Helper: create a file (and parent dirs) inside a QTemporaryDir.
    static void createFile(const QString& basePath, const QString& relativePath) {
        const QString fullPath = basePath + u'/' + relativePath;
        QDir().mkpath(QFileInfo(fullPath).path());
        QFile f(fullPath);
        f.open(QIODevice::WriteOnly);
        f.write("x");
        f.close();
    }

    // Helper: create a directory inside a QTemporaryDir.
    static void createDir(const QString& basePath, const QString& relativePath) {
        QDir().mkpath(basePath + u'/' + relativePath);
    }

    // Helper: wait for scanning to complete.
    static bool waitForScan(FuzzyFinder& model, int timeout = 5000) {
        if (!model.scanning())
            return true;
        QSignalSpy spy(&model, &FuzzyFinder::scanningChanged);
        while (model.scanning()) {
            if (!spy.wait(timeout))
                return false;
        }
        return true;
    }

    // Helper: wait for scoring to complete (loading becomes false).
    static bool waitForScore(FuzzyFinder& model, int timeout = 5000) {
        if (!model.loading())
            return true;
        QSignalSpy spy(&model, &FuzzyFinder::loadingChanged);
        while (model.loading()) {
            if (!spy.wait(timeout))
                return false;
        }
        return true;
    }

private slots:

    void modelTester() {
        FuzzyFinder model;
        QAbstractItemModelTester tester(
            &model, QAbstractItemModelTester::FailureReportingMode::QtTest);

        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "hello.txt");

        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("hello");
        QVERIFY(waitForScore(model));

        QVERIFY(model.resultCount() > 0);
    }

    void basicScan() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "a.txt");
        createFile(tmp.path(), "b.txt");
        createDir(tmp.path(), "sub");
        createFile(tmp.path(), "sub/c.txt");

        FuzzyFinder model;
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        // No query → 0 results, but paths are cached internally
        QCOMPARE(model.resultCount(), 0);

        // Query that matches all files
        model.setQuery("txt");
        QVERIFY(waitForScore(model));
        QCOMPARE(model.resultCount(), 3);
    }

    void queryScoring() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "target.txt");
        createFile(tmp.path(), "deep/nested/target.txt");
        createFile(tmp.path(), "other.txt");

        FuzzyFinder model;
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("target");
        QVERIFY(waitForScore(model));

        QCOMPARE(model.resultCount(), 2);

        // First result should be the shallow "target.txt" (filename bonus + less depth penalty)
        const QModelIndex first = model.index(0, 0);
        QCOMPARE(model.data(first, FuzzyFinder::NameRole).toString(), "target.txt");
        QCOMPARE(model.data(first, FuzzyFinder::PathRole).toString(), "target.txt");

        // Second should be the deeper one
        const QModelIndex second = model.index(1, 0);
        QVERIFY(model.data(second, FuzzyFinder::PathRole).toString().contains("deep"));

        // First score should be >= second score
        QVERIFY(model.data(first, FuzzyFinder::ScoreRole).toInt()
                >= model.data(second, FuzzyFinder::ScoreRole).toInt());
    }

    void emptyQuery() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "file.txt");

        FuzzyFinder model;
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("");
        // Empty query should yield 0 results immediately (no async needed)
        QCOMPARE(model.resultCount(), 0);
    }

    void showHiddenRespected() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "visible.txt");
        createFile(tmp.path(), ".hidden.txt");

        // Default: showHidden = false → dotfiles excluded
        FuzzyFinder model;
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("txt");
        QVERIFY(waitForScore(model));
        QCOMPARE(model.resultCount(), 1);

        // Enable showHidden → both visible
        model.setShowHidden(true);
        QVERIFY(waitForScan(model));
        QVERIFY(waitForScore(model));
        QCOMPARE(model.resultCount(), 2);
    }

    void gitignoreBasic() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "keep.txt");
        createFile(tmp.path(), "debug.log");
        createFile(tmp.path(), "error.log");

        // Create .gitignore that ignores *.log
        {
            QFile f(tmp.path() + "/.gitignore");
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write("*.log\n");
            f.close();
        }

        FuzzyFinder model;
        model.setShowHidden(true);  // need to see .gitignore to parse it
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        // Search for everything
        model.setQuery("e");
        QVERIFY(waitForScore(model));

        // Should only find keep.txt (and .gitignore itself), not the .log files
        for (int i = 0; i < model.resultCount(); ++i) {
            const QString path = model.data(model.index(i, 0), FuzzyFinder::PathRole).toString();
            QVERIFY2(!path.endsWith(".log"),
                qPrintable("Gitignored file found in results: " + path));
        }
    }

    void gitignoreNegation() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "debug.log");
        createFile(tmp.path(), "important.log");

        // .gitignore: ignore all .log except important.log
        {
            QFile f(tmp.path() + "/.gitignore");
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write("*.log\n!important.log\n");
            f.close();
        }

        FuzzyFinder model;
        model.setShowHidden(true);
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("log");
        QVERIFY(waitForScore(model));

        // Should find important.log but not debug.log
        bool foundImportant = false;
        for (int i = 0; i < model.resultCount(); ++i) {
            const QString name = model.data(model.index(i, 0), FuzzyFinder::NameRole).toString();
            if (name == "important.log")
                foundImportant = true;
            QVERIFY2(name != "debug.log",
                "debug.log should be excluded by gitignore");
        }
        QVERIFY2(foundImportant, "important.log should be included via negation");
    }

    void gitDirExcluded() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "file.txt");
        createDir(tmp.path(), ".git");
        createFile(tmp.path(), ".git/config");
        createFile(tmp.path(), ".git/HEAD");

        FuzzyFinder model;
        model.setShowHidden(true);  // even with showHidden, .git/ should be skipped
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("config");
        QVERIFY(waitForScore(model));

        // .git/config should NOT appear
        for (int i = 0; i < model.resultCount(); ++i) {
            const QString path = model.data(model.index(i, 0), FuzzyFinder::PathRole).toString();
            QVERIFY2(!path.contains(".git/"),
                qPrintable(".git/ content found in results: " + path));
        }
    }

    void resultCap() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());

        // Create 250 files that all match query "f"
        for (int i = 0; i < 250; ++i) {
            createFile(tmp.path(), QStringLiteral("file_%1.txt").arg(i, 3, 10, QChar(u'0')));
        }

        FuzzyFinder model;
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("file");
        QVERIFY(waitForScore(model));

        QCOMPARE(model.resultCount(), FuzzyFinder::MaxResults);
    }

    void matchIndices() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "format.js");

        FuzzyFinder model;
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("fjs");
        QVERIFY(waitForScore(model));

        QVERIFY(model.resultCount() > 0);

        const QVariantList indices =
            model.data(model.index(0, 0), FuzzyFinder::MatchIndicesRole).toList();

        // Should have 3 indices (one per query char)
        QCOMPARE(indices.size(), 3);

        // Indices should be in ascending order
        for (int i = 1; i < indices.size(); ++i) {
            QVERIFY(indices[i].toInt() > indices[i - 1].toInt());
        }
    }

    void generationStale() {
        QTemporaryDir tmp1;
        QVERIFY(tmp1.isValid());
        createFile(tmp1.path(), "first.txt");

        QTemporaryDir tmp2;
        QVERIFY(tmp2.isValid());
        createFile(tmp2.path(), "second.txt");

        FuzzyFinder model;

        // Set first path, then immediately set second path.
        // The generation counter is incremented synchronously in setSearchPath,
        // so the first walk's result is discarded even if it arrives last.
        model.setSearchPath(tmp1.path());
        model.setSearchPath(tmp2.path());

        QVERIFY(waitForScan(model));

        model.setQuery("txt");
        QVERIFY(waitForScore(model));

        // Should only have results from second directory
        QCOMPARE(model.resultCount(), 1);
        QCOMPARE(model.data(model.index(0, 0), FuzzyFinder::NameRole).toString(), "second.txt");
    }

    void filenameBonus() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "src/utils/helpers/config.js");
        createFile(tmp.path(), "config.js");

        FuzzyFinder model;
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("config");
        QVERIFY(waitForScore(model));

        QVERIFY(model.resultCount() >= 2);

        // Root-level config.js should rank first (less depth + same filename bonus)
        QCOMPARE(model.data(model.index(0, 0), FuzzyFinder::PathRole).toString(), "config.js");
    }

    void clearReleasesMemory() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "file.txt");

        FuzzyFinder model;
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("file");
        QVERIFY(waitForScore(model));
        QVERIFY(model.resultCount() > 0);

        model.clear();
        QCOMPARE(model.resultCount(), 0);
        QVERIFY(!model.scanning());
        QVERIFY(!model.loading());
        QVERIFY(model.searchPath().isEmpty());
        QVERIFY(model.query().isEmpty());
    }

    void isDirRole() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "file.txt");
        createDir(tmp.path(), "folder");

        FuzzyFinder model;
        model.setSearchPath(tmp.path());
        QVERIFY(waitForScan(model));

        model.setQuery("f");
        QVERIFY(waitForScore(model));

        bool foundFile = false;
        bool foundDir = false;
        for (int i = 0; i < model.resultCount(); ++i) {
            const QModelIndex idx = model.index(i, 0);
            const bool isDir = model.data(idx, FuzzyFinder::IsDirRole).toBool();
            const QString name = model.data(idx, FuzzyFinder::NameRole).toString();
            if (name == "file.txt") {
                QVERIFY(!isDir);
                foundFile = true;
            } else if (name == "folder") {
                QVERIFY(isDir);
                foundDir = true;
            }
        }
        QVERIFY(foundFile);
        QVERIFY(foundDir);
    }
    void queryBeforeWalkCompletes() {
        // Tests the code path where setQuery is called before the async walk
        // finishes. startScoring() returns early when m_cachedPaths is empty;
        // the walk-completion handler then calls startScoring() automatically.
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        createFile(tmp.path(), "hello.txt");
        createFile(tmp.path(), "world.txt");

        FuzzyFinder model;

        // Set the query BEFORE setting the path (before the walk even starts)
        model.setQuery("hello");

        // Now start the walk — the walk completion handler should auto-score
        model.setSearchPath(tmp.path());

        // Wait for the walk + scoring to complete
        QVERIFY(waitForScan(model));
        QVERIFY(waitForScore(model));

        // Should find the file despite the query arriving before the walk
        QVERIFY(model.resultCount() > 0);
        bool found = false;
        for (int i = 0; i < model.resultCount(); ++i) {
            if (model.data(model.index(i, 0), FuzzyFinder::NameRole).toString() == "hello.txt") {
                found = true;
                break;
            }
        }
        QVERIFY2(found, "hello.txt should be found when query was set before walk started");
    }

};

QTEST_MAIN(FuzzyFinderTest)
#include "FuzzyFinderTest.moc"
