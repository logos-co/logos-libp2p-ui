import QtQuick
import Logos.Theme

Canvas {
    id: root

    property var history: []
    property int windowMinutes: 15
    property string firstField: "receiveRate"
    property string secondField: "sendRate"
    property color firstColor: "#2563EB"
    property color secondColor: "#16A34A"

    implicitHeight: 220

    function visiblePoints() {
        if (!history || history.length === 0)
            return []
        var cutoff = Date.now() - windowMinutes * 60000
        var points = []
        for (var i = 0; i < history.length; ++i) {
            if ((history[i].timestampMs || 0) >= cutoff)
                points.push(history[i])
        }
        return points
    }

    function drawSeries(context, points, field, color, maximum, left, top, plotWidth, plotHeight) {
        if (points.length < 2 || maximum <= 0)
            return
        context.beginPath()
        context.strokeStyle = color
        context.lineWidth = 2
        for (var i = 0; i < points.length; ++i) {
            var x = left + i * plotWidth / Math.max(1, points.length - 1)
            var y = top + plotHeight - Math.max(0, Number(points[i][field] || 0)) * plotHeight / maximum
            if (i === 0)
                context.moveTo(x, y)
            else
                context.lineTo(x, y)
        }
        context.stroke()
    }

    onHistoryChanged: requestPaint()
    onWindowMinutesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var context = getContext("2d")
        context.reset()
        var left = 10
        var top = 10
        var plotWidth = Math.max(1, width - 20)
        var plotHeight = Math.max(1, height - 20)
        context.strokeStyle = Theme.palette.borderSecondary
        context.lineWidth = 1
        for (var grid = 0; grid <= 4; ++grid) {
            var gridY = top + grid * plotHeight / 4
            context.beginPath()
            context.moveTo(left, gridY)
            context.lineTo(left + plotWidth, gridY)
            context.stroke()
        }

        var points = visiblePoints()
        var maximum = 0
        for (var i = 0; i < points.length; ++i)
            maximum = Math.max(maximum, Number(points[i][firstField] || 0), Number(points[i][secondField] || 0))
        drawSeries(context, points, firstField, firstColor, maximum, left, top, plotWidth, plotHeight)
        drawSeries(context, points, secondField, secondColor, maximum, left, top, plotWidth, plotHeight)
    }
}
