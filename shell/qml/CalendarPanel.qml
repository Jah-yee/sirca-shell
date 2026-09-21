// The popup behind the clock, native: a large live clock with the date, and a month calendar. Click the month title to
// zoom out to months, again to years; arrows and the mouse wheel page through; "Today" jumps back. The first day of the
// week and all names come from the system locale. No Plasma applet, no data source: dates are computed here.
import QtQuick
import org.kde.kirigami as Kirigami
import SircaShell

Item {
    id: cal
    property bool open: false
    implicitWidth: 348
    implicitHeight: col.implicitHeight + 12
    readonly property var loc: Qt.locale()
    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: cal.open; triggeredOnStart: true; onTriggered: cal.now = new Date() }
    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()             // 0..11
    property date selected: new Date()
    property string zoom: "days"                        // "days" | "months" | "years"
    onOpenChanged: if (open) { const d = new Date(); now = d; viewYear = d.getFullYear(); viewMonth = d.getMonth(); selected = d; zoom = "days" }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
    function page(step) {
        if (zoom === "days") { const m = viewMonth + step; viewYear += Math.floor(m / 12); viewMonth = ((m % 12) + 12) % 12 }
        else if (zoom === "months") viewYear += step; else viewYear += 12 * step }
    // 42 cells starting at the locale's first weekday on or before the 1st
    readonly property var cells: { const first = new Date(viewYear, viewMonth, 1); const shift = (first.getDay() - loc.firstDayOfWeek + 7) % 7; const out = [];
        for (let i = 0; i < 42; ++i) out.push(new Date(viewYear, viewMonth, 1 - shift + i)); return out }
    function isoWeek(d) { const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate())); const n = t.getUTCDay() || 7; t.setUTCDate(t.getUTCDate() + 4 - n);
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1)); return Math.ceil(((t - y0) / 86400000 + 1) / 7) }

    component RoundBtn: Item { id: rb; property string icon; signal tapped()
        width: 30; height: 30
        Rectangle { anchors.fill: parent; radius: 15; color: Config.fg(rt.pressed ? 0.20 : (rbh.hovered ? 0.12 : 0.055)); border.width: 1; border.color: Config.fg(rbh.hovered ? 0.18 : 0.09)
            Behavior on color { ColorAnimation { duration: Config.quick } } }
        Kirigami.Icon { anchors.centerIn: parent; width: 13; height: 13; source: rb.icon; isMask: true; color: Config.fgSolid; opacity: 0.9; roundToIconSize: false }
        HoverHandler { id: rbh } TapHandler { id: rt; onTapped: rb.tapped() } }

    Column { id: col; x: 6; y: 6; width: parent.width - 12; spacing: 10
        // ---- clock ----
        Column { width: parent.width; spacing: 0
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                readonly property string shortTime: cal.now.toLocaleTimeString(cal.loc, Locale.ShortFormat)
                readonly property var ampm: shortTime.match(/[AP]M$/i)
                Text { id: big; color: Config.ink; font.pixelSize: 44; font.weight: Font.Light; font.letterSpacing: -1; font.features: { "tnum": 1 }
                    text: parent.shortTime.replace(/\s?[AP]M$/i, "") + ":" + String(cal.now.getSeconds()).padStart(2, "0") }
                Text { visible: !!parent.ampm; anchors.baseline: big.baseline; color: Config.inkDim; font.pixelSize: 16; font.weight: Font.Medium; text: parent.ampm ? parent.ampm[0] : "" } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; color: Config.inkDim; font.pixelSize: 13; text: cal.now.toLocaleDateString(cal.loc, "dddd, d MMMM yyyy") } }
        Rectangle { width: parent.width - 12; x: 6; height: 1; color: Config.fg(0.08) }

        // ---- header: title (zooms out), today, arrows ----
        Item { width: parent.width; height: 32
            Rectangle { id: titlePill; height: 30; width: title.implicitWidth + 22; radius: 15; anchors.verticalCenter: parent.verticalCenter
                color: Config.fg(th.hovered ? 0.10 : 0); Behavior on color { ColorAnimation { duration: Config.quick } }
                Text { id: title; anchors.centerIn: parent; color: Config.ink; font.pixelSize: 15; font.weight: Font.DemiBold
                    text: cal.zoom === "days" ? cal.loc.standaloneMonthName(cal.viewMonth) + " " + cal.viewYear : cal.zoom === "months" ? String(cal.viewYear) : (cal.viewYear - cal.viewYear % 12) + " – " + (cal.viewYear - cal.viewYear % 12 + 11) }
                HoverHandler { id: th } TapHandler { onTapped: cal.zoom = cal.zoom === "days" ? "months" : "years" } }
            Row { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Rectangle { height: 30; width: tl.implicitWidth + 22; radius: 15; anchors.verticalCenter: parent.verticalCenter
                    color: Config.fg(tdh.hovered ? 0.12 : 0.055); border.width: 1; border.color: Config.fg(0.09)
                    Text { id: tl; anchors.centerIn: parent; text: "Today"; color: Config.ink; font.pixelSize: 12; font.weight: Font.Medium }
                    HoverHandler { id: tdh } TapHandler { onTapped: { const d = new Date(); cal.viewYear = d.getFullYear(); cal.viewMonth = d.getMonth(); cal.selected = d; cal.zoom = "days" } } }
                RoundBtn { icon: "go-previous-symbolic"; onTapped: cal.page(-1) }
                RoundBtn { icon: "go-next-symbolic"; onTapped: cal.page(1) } } }

        // ---- the views share one box, so the popup never changes size between them ----
        Item { id: views; width: parent.width; height: 22 + 6 * 40
            WheelHandler { onWheel: e => cal.page(e.angleDelta.y > 0 ? -1 : 1) }
            // days
            Item { anchors.fill: parent; opacity: cal.zoom === "days" ? 1 : 0; visible: opacity > 0.01; scale: cal.zoom === "days" ? 1 : 0.94
                Behavior on opacity { NumberAnimation { duration: 160 } } Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Row { id: names; width: parent.width; height: 22
                    Repeater { model: 7
                        Text { required property int index; width: names.width / 7; horizontalAlignment: Text.AlignHCenter; color: Config.inkDim; font.pixelSize: 11; font.weight: Font.Medium; font.capitalization: Font.AllUppercase
                            text: cal.loc.standaloneDayName((cal.loc.firstDayOfWeek + index) % 7, Locale.ShortFormat) } } }
                Grid { y: 22; width: parent.width; columns: 7
                    Repeater { model: cal.cells
                        Item { id: cell; required property var modelData
                            readonly property bool inMonth: modelData.getMonth() === cal.viewMonth
                            readonly property bool today: cal.sameDay(modelData, cal.now)
                            readonly property bool picked: cal.sameDay(modelData, cal.selected) && !today
                            width: views.width / 7; height: 40
                            Rectangle { anchors.centerIn: parent; width: 34; height: 34; radius: 17
                                color: cell.today ? Config.onFill : Config.fg(dh.hovered ? 0.10 : 0)
                                border.width: cell.picked ? 1 : 0; border.color: Config.fg(0.45)
                                Behavior on color { ColorAnimation { duration: Config.quick } } }
                            Text { anchors.centerIn: parent; text: cell.modelData.getDate(); font.pixelSize: 13; font.weight: cell.today ? Font.DemiBold : Font.Normal; font.features: { "tnum": 1 }
                                color: cell.today ? Config.onFg : Config.ink
                                opacity: cell.today ? 1 : (!cell.inMonth ? 0.28 : ((cell.modelData.getDay() === 0 || cell.modelData.getDay() === 6) ? 0.62 : 1)) }
                            HoverHandler { id: dh }
                            TapHandler { onTapped: { cal.selected = cell.modelData; if (!cell.inMonth) { cal.viewYear = cell.modelData.getFullYear(); cal.viewMonth = cell.modelData.getMonth() } } } } } } }
            // months and years: 4 x 3 pills
            Repeater { model: ["months", "years"]
                Grid { id: big; required property string modelData; anchors.fill: parent; columns: 3
                    opacity: cal.zoom === modelData ? 1 : 0; visible: opacity > 0.01; scale: cal.zoom === modelData ? 1 : 1.06
                    Behavior on opacity { NumberAnimation { duration: 160 } } Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Repeater { model: 12
                        Item { id: bc; required property int index; width: views.width / 3; height: views.height / 4
                            readonly property int year: cal.viewYear - cal.viewYear % 12 + index
                            readonly property bool current: big.modelData === "months" ? (index === cal.now.getMonth() && cal.viewYear === cal.now.getFullYear()) : year === cal.now.getFullYear()
                            Rectangle { anchors.centerIn: parent; width: parent.width - 12; height: 40; radius: 20
                                color: bc.current ? Config.fg(0.16) : Config.fg(bh.hovered ? 0.10 : 0); border.width: 1; border.color: Config.fg(bc.current ? 0.24 : 0)
                                Behavior on color { ColorAnimation { duration: Config.quick } } }
                            Text { anchors.centerIn: parent; color: Config.ink; font.pixelSize: 13; font.weight: bc.current ? Font.DemiBold : Font.Normal
                                text: big.modelData === "months" ? cal.loc.standaloneMonthName(bc.index, Locale.ShortFormat) : String(bc.year) }
                            HoverHandler { id: bh }
                            TapHandler { onTapped: { if (big.modelData === "months") { cal.viewMonth = bc.index; cal.zoom = "days" } else { cal.viewYear = bc.year; cal.zoom = "months" } } } } } } } }

        // ---- the picked day ----
        Rectangle { width: parent.width - 12; x: 6; height: 1; color: Config.fg(0.08) }
        Item { width: parent.width; height: 22
            Text { x: 8; anchors.verticalCenter: parent.verticalCenter; color: Config.ink; font.pixelSize: 13; text: cal.selected.toLocaleDateString(cal.loc, "dddd, d MMMM") }
            Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; color: Config.inkDim; font.pixelSize: 12; text: "Week " + cal.isoWeek(cal.selected) } }
    }
}
