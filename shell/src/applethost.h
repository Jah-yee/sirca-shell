// QML item that shows a hosted Plasma applet: AppletHost { plugin: "onur.glasscontrol"; zone: "lobe" }
#pragma once
#include <QPointer>
#include <QQuickItem>
#include <qqml.h>

class AppletHost : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString plugin READ plugin WRITE setPlugin NOTIFY pluginChanged)
    Q_PROPERTY(QString zone READ zone WRITE setZone NOTIFY zoneChanged)
    Q_PROPERTY(QQuickItem *appletItem READ appletItem NOTIFY appletItemChanged)
    Q_PROPERTY(bool expanded READ expanded WRITE setExpanded NOTIFY expandedChanged)
public:
    explicit AppletHost(QQuickItem *parent = nullptr);
    QString plugin() const { return m_plugin; }
    void setPlugin(const QString &p);
    QString zone() const { return m_zone; }
    void setZone(const QString &z);
    QQuickItem *appletItem() const { return m_item; }
    bool expanded() const;
    void setExpanded(bool e);
Q_SIGNALS:
    void pluginChanged();
    void zoneChanged();
    void appletItemChanged();
    void expandedChanged();
protected:
    void componentComplete() override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
private Q_SLOTS:
    void adoptFullRepresentation();
    void onAppletExpandedChanged();
private:
    void attach();
    QString m_plugin;
    QString m_zone = QStringLiteral("lobe");
    QPointer<QQuickItem> m_item;
    QPointer<QQuickItem> m_full;
    bool m_warming = false;
    bool m_wantExpanded = false;
};
