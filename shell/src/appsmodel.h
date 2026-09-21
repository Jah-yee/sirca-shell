#pragma once
// Every installed application, straight from KService (the same database Kickoff reads). No Plasma applet involved:
// this is what lets the launcher stand on its own. Filtered in C++ by free text and by one main category.
#include <QAbstractListModel>
#include <QStringList>
#include <QVariantMap>
#include <qqml.h>

class AppsModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY categoryChanged)     // "" = all
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QStringList categories READ categories NOTIFY categoriesChanged)            // the ones that have apps
public:
    enum Roles { NameRole = Qt::UserRole + 1, GenericRole, IconRole, StorageIdRole, CommentRole };
    explicit AppsModel(QObject *parent = nullptr);
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    QString filter() const { return m_filter; }
    void setFilter(const QString &f);
    QString category() const { return m_category; }
    void setCategory(const QString &c);
    int count() const { return m_rows.size(); }
    QStringList categories() const { return m_categories; }
    Q_INVOKABLE bool launch(const QString &storageId);
    Q_INVOKABLE QVariantMap info(const QString &storageId) const;       // {name, icon, storageId} or {} (for pinned apps)
    Q_INVOKABLE QString storageIdAt(int row) const;
Q_SIGNALS:
    void filterChanged();
    void categoryChanged();
    void countChanged();
    void categoriesChanged();
private:
    struct App { QString name, generic, comment, icon, storageId, path, haystack; QStringList cats; };
    void reload();
    void refilter();
    static QString mainCategory(const QStringList &cats);
    QList<App> m_apps;
    QList<int> m_rows;
    QString m_filter, m_category;
    QStringList m_categories;
};
