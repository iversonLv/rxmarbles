Rx = require 'rx'
XMLNS = "http://www.w3.org/2000/svg"

#
# Renders a circle or similar shape to represent an emitted item on a stream
#

NUM_COLORS = 4

getDxDragStream = (element) ->
  return Rx.Observable.fromEvent(element, "mousedown")
    .map( ->
      moveStream = Rx.Observable.fromEvent(document, "mousemove")
      upStream = Rx.Observable.fromEvent(document, "mouseup")
      dxStream = moveStream
        .map((ev) ->
          ev.stopPropagation
          ev.preventDefault()
          return ev.pageX
        )
        .windowWithCount(2,1)
        .flatMap((result) -> result.toArray())
        .map((array) -> (array[1] - array[0]))
      return dxStream.takeUntil(upStream)
    )
    .concatAll()

getLeftPosStream = (element, initialPos) ->
  return getDxDragStream(element)
    .scan(initialPos, (acc, dx) ->
      pxToPercentage = 1
      try
        pxToPercentage = 100.0 / (element.parentElement.clientWidth)
      catch err
        console.warn(err)
      return acc + (dx * pxToPercentage)
    )
    .map((pos) ->
      return 0 if pos < 0
      return 100 if pos > 100
      return pos
    )
    .map(Math.round)
    .startWith(initialPos)
    .distinctUntilChanged()

createMarbleSvg = (item) ->
  colornum = (item.id % NUM_COLORS) + 1
  marble = document.createElementNS(XMLNS, "svg")
  marble.setAttributeNS(null, "class", "marble")
  marble.setAttributeNS(null, "viewBox", "0 0 1 1")
  circle = document.createElementNS(XMLNS, "circle")
  circle.setAttributeNS(null, "cx", 0.5)
  circle.setAttributeNS(null, "cy", 0.5)
  circle.setAttributeNS(null, "r", 0.5)
  circle.setAttributeNS(null, "class", "marble marble-color-#{colornum}")
  circle.style["stroke-width"] = "0.07"
  marble.appendChild(circle)
  return marble

createContentElement = (item) ->
  content = document.createElement("p")
  content.className = "marble-content"
  content.textContent = item?.content
  return content

module.exports = {
  render: (item) ->
    container = document.createElement("div")
    container.className = "marble-container"

    container.appendChild(createMarbleSvg(item))
    container.appendChild(createContentElement(item))

    leftPosStream = getLeftPosStream(container, item.time)

    container.dataStream = leftPosStream
      .map((leftPos) -> {t:leftPos, d:item.content})

    leftPosStream
      .subscribe((leftPos) ->
        container.style.left = leftPos + "%"
        return true
      )

    return container
}
