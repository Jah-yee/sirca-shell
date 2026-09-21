// Screenshot source for the shell's own capture overlay. One frame of the whole screen is taken from the window manager
// (org.kde.KWin.ScreenShot2, allowed through X-KDE-DBUS-Restricted-Interfaces in sirca-shell.desktop) and kept in memory;
// the overlay shows that frozen frame, and what the user selects is cut out of it, saved and put on the clipboard.
#pragma once
#include <QImage>
#include <QObject>
#include <QQuickImageProvider>
#include <QRect>
#include <qqmlintegration.h>

class Screenshot : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool ready READ ready NOTIFY frameChanged)
    Q_PROPERTY(int revision READ revision NOTIFY frameChanged)          // changes with every frame: part of the image url
    Q_PROPERTY(QString folder READ folder CONSTANT)
public:
    explicit Screenshot(QObject *parent = nullptr);
    static QImage frame();                                               // for the image provider (any thread)
    bool ready() const;
    int revision() const { return m_revision; }
    QString folder() const;
    Q_INVOKABLE void grab(const QString &screenName);                    // asks for a frame; frameChanged or failed follows
    Q_INVOKABLE void useFile(const QString &path);                       // preview and tests: a picture instead of the screen
    // rect in the overlay's logical pixels; clipboard/save say where the cut goes. Returns the saved path ("" if not saved)
    Q_INVOKABLE QString finish(qreal x, qreal y, qreal w, qreal h, qreal overlayWidth, bool clipboard, bool save);
    Q_INVOKABLE QString newVideoPath(const QString &extension) const;   // ~/Videos/Screencasts/Recording_<time>.<ext>, folder created
    Q_INVOKABLE bool discardIfEmpty(const QString &path) const;   // a recording with no frames (nothing moved): remove it, true
    Q_INVOKABLE void drop();                                             // forget the frame (cancel, or done)
Q_SIGNALS:
    void frameChanged();
    void failed(const QString &why);
    void saved(const QString &path, int width, int height);
private:
    int m_revision = 0;
};

class ShotImageProvider : public QQuickImageProvider
{
public:
    ShotImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString &, QSize *size, const QSize &) override { const QImage i = Screenshot::frame(); if (size) *size = i.size(); return i; }
};
