#pragma once

// FuzzyFinder — QML element for fzf-style recursive fuzzy file searching.
//
// Scans a directory tree asynchronously via QtConcurrent, caches all paths,
// then scores them against a query string using Smith-Waterman subsequence
// matching. Results are capped at 200 and exposed as a QAbstractListModel.
//
// Key design decisions:
//
//   1. Walk-once / score-many — the directory scan (I/O-bound) runs once when
//      searchPath changes. Subsequent query keystrokes only re-score the cached
//      path list (CPU-bound), which keeps typing feel instant.
//
//   2. Two generation counters — m_walkGeneration guards the async directory
//      walk, m_scoreGeneration guards the async scoring pass. Both use the
//      ArchivePreviewModel pattern: capture before dispatch, check on arrival.
//
//   3. Gitignore-aware traversal — parses .gitignore files at each directory
//      level during the walk, stacking rules so children override parents.
//      Always skips .git/ directories. Respects showHidden.
//
//   4. Smith-Waterman scoring — the same algorithm family as fzf and fff.nvim.
//      Bonuses for word boundaries, consecutive matches, filename region, and
//      exact case. Path depth penalty favours shallower results.

#include <qabstractitemmodel.h>
#include <qobject.h>
#include <qqmlintegration.h>

namespace symmetria::filemanager::models {

struct CachedPath {
    QString relativePath;  // relative to searchPath ("src/utils/format.js")
    QString name;          // filename component ("format.js")
    QString fullPath;      // absolute path
    bool    isDir;
    int     depth;         // number of '/' in relativePath
};

struct FuzzyMatchResult {
    QString      relativePath;
    QString      name;
    QString      fullPath;
    bool         isDir;
    int          score;
    QVector<int> matchIndices;  // character positions in relativePath
};

class FuzzyFinder : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    // Input properties
    Q_PROPERTY(QString searchPath READ searchPath WRITE setSearchPath NOTIFY searchPathChanged)
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY queryChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)

    // Output properties
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int resultCount READ resultCount NOTIFY resultCountChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    enum Roles {
        PathRole = Qt::UserRole,
        NameRole,
        IsDirRole,
        ScoreRole,
        MatchIndicesRole,
        FullPathRole,
    };
    Q_ENUM(Roles)

    explicit FuzzyFinder(QObject* parent = nullptr);

    // QAbstractListModel overrides
    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    [[nodiscard]] QString searchPath() const;
    void setSearchPath(const QString& path);

    [[nodiscard]] QString query() const;
    void setQuery(const QString& query);

    [[nodiscard]] bool showHidden() const;
    void setShowHidden(bool show);

    [[nodiscard]] bool scanning() const;
    [[nodiscard]] bool loading() const;
    [[nodiscard]] int resultCount() const;
    [[nodiscard]] QString error() const;

    Q_INVOKABLE void clear();

    static constexpr int MaxResults = 200;
    // Hard cap on the recursive walk to keep enormous directories
    // (~/Downloads with 270k files, monorepos with node_modules, etc.)
    // from making the picker appear hung. When hit, the walker returns
    // early with whatever was collected and sets `error` so the popup
    // can warn the user that results are incomplete.
    static constexpr int MaxScanFiles = 50000;

signals:
    void searchPathChanged();
    void queryChanged();
    void showHiddenChanged();
    void scanningChanged();
    void loadingChanged();
    void resultCountChanged();
    void errorChanged();

private:
    void startWalk();
    void startScoring();

    QString m_searchPath;
    QString m_query;
    bool    m_showHidden = false;

    QVector<CachedPath>       m_cachedPaths;
    QVector<FuzzyMatchResult> m_results;

    bool    m_scanning = false;
    bool    m_loading = false;
    QString m_error;

    int m_walkGeneration  = 0;
    int m_scoreGeneration = 0;
};

} // namespace symmetria::filemanager::models
