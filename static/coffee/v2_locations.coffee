$(->
  # generate our gradient
  colors = gradientFactory.generate({
    from: '#DDDDDD'
    to: primaryColor
    stops: 7
  })

  # breaks for each gradient
  breaks = [0, 5, 10, 25, 45, 65, 85]

  # default empty style
  emptyStyle = (feature) ->
    return {
      fillColor: colors[1]
      weight: 1
      opacity: 1
      color: 'white'
      fillOpacity: 0.7
    }

  highlightStyle = {
    weight: 3
    fillOpacity: 1
  }

  # our leaflet options
  options = {
      # no user controlled zooming
      zoomControl:false
      scrollWheelZoom: false
      doubleClickZoom: false
      boxZoom: false

      # allow arbitrary scaling
      zoomSnap: 0

      # remove leaflet attribution
      attributionControl: false

      # don't allow dragging
      dragging: false
  }

  initMap = (id, geojson, url, districtZoom, wardZoom) ->
    map = L.map(id, options)

    # constants
    STATE_LEVEL = 1
    DISTRICT_LEVEL = 2
    WARD_LEVEL = 3
  
    boundaries = null
    boundaryResults = null
  
    states = null
    stateResults = null
  
    info = null
    
    overallResults = null
    countryResults = null

    # this is our info box floating off in the top right
    info = new L.control()
  
    info.onAdd = (map) ->
      this._div = L.DomUtil.create('div', 'leaflet-info');
      newParent = document.getElementById('map-info')
      console.log(newParent)
      oldParent = document.getElementsByClassName('leaflet-control-container')[0]
      console.log(oldParent)
      newParent.appendChild(oldParent)
      
      this.update()
      return this._div
    
    hiddenStyle = (feature) ->
      return {
        fillOpacity: 0.0
        opacity: 0.0
      }

    info.update = (props) ->
      if props
        if props.count?
          if props.count.unset?
            total = props.count.set + props.count.unset
            this._div.innerHTML = "<div class='name'>" + props.name + "</div>" +
              "<div class='count'>" + props.count.set + " of " + total + "</div>"
          else if props.count.set?
            this._div.innerHTML = "<div class='name'>" + props.name + "</div>" +
              "<div class='count'>" + props.count.set + "</div>"
          else
            this._div.innerHTML = "<div class='name'>" + props.name + "</div>"
      #   else
      #     this._div.innerHTML = ""
      # else
      #   this._div.innerHTML = ""
  
    # rollover treatment
    highlight = (e) ->
      layer = e.target
      layer.setStyle(highlightStyle)
      if (!L.Browser.ie && !L.Browser.opera && !L.Browser.edge)
        layer.bringToFront()
  
      info.update(e.target.feature.properties)
  
    clickFeature = (e) ->
      if (districtZoom and e.target.feature.properties.level == STATE_LEVEL)
        loadBoundary(url, e.target.feature.properties, e.target)
      else if (wardZoom and e.target.feature.properties.level == DISTRICT_LEVEL)
        map.removeLayer(boundaries)
        loadBoundary(url, e.target.feature.properties, e.target)
      else
        resetBoundaries()
  
    # resets our color on mouseout
    reset = (e) ->
      boundaries.resetStyle(e.target)
      info.update()
    
    # looks up the color for the passed in feature
    countStyle = (feature) ->
      return {
        fillColor: feature.properties.color
        weight: 1
        opacity: 1
        color: 'white'
        fillOpacity: 0.7
      }
  
    onEachFeature = (feature, layer) ->
      layer.on({
        mouseover: highlight
        mouseout: reset
        click: clickFeature
      });
  
    resetBoundaries = ->
      console.log(boundaries)
      map.removeLayer(boundaries) 
  
      boundaries = states
      boundaryResults = stateResults
  
      states.setStyle(countStyle)
      map.addLayer(states)
      map.fitBounds(states.getBounds(), {step: .25})
  
      overallResults = countryResults
      info.update()
  
    loadBoundary = (url, boundary, target) ->
      boundaryId = if boundary then boundary.id else null
      boundaryLevel = if boundary then boundary.level else null
  
      # load our actual data
      if not boundary
        segment = {location:"State"}
        overallResults = countryResults
      else if boundary and boundary.level == DISTRICT_LEVEL
        segment = {location:"Ward", parent:boundaryId}
        overallResults = boundaryResults[boundaryId]
      else
        segment = {location:"District", parent:boundaryId}
        overallResults = boundaryResults[boundaryId]
  
      console.log(url)
      $.ajax({url: url + '?segment=' + encodeURIComponent(JSON.stringify(segment)), dataType: "json"}).done (counts) ->
        countMap = {}
        console.log(counts)
  
        # figure out our max value
        max = 0;
        boundaryResults = {}
        for count in counts
          countMap[count.boundary] = count
          if (count.set > max)
            max = count.set
          
          boundaryResults[count['boundary']] = count
  
        console.log(max)
        
        # and create mapping of threshold values to colors
        colorSteps = []
        for color, i in colors
          colorSteps[i] = {
            threshold: max * (breaks[i] / 100)
            color: colors[i]
          }
  


        console.log(countMap)
        console.log(colorSteps)
  
        # we are displaying the districts of a state, load the geojson for it
        boundaryUrl = '/boundaries/'
        if boundaryId
          boundaryUrl += boundaryId + '/'
  
        $.ajax({url:boundaryUrl, dataType: "json"}).done (data) ->
          # added to reset boundary when district has no wards
          if data.features.length == 0
            resetBoundaries()
            return
  
          console.log(data);
          for feature in data.features
            props = feature.properties
            count = countMap[props.id].set
  
            # merge our count values in
            props.count = countMap[props.id]
  
            props.color = colorSteps[colorSteps.length-1].color
            for step in colorSteps
              if count <= step.threshold
                props.color = step.color
                break

          boundaries = L.geoJSON(data, {
            style: countStyle,
            onEachFeature: onEachFeature
          })
          boundaries.addTo(map);

          if boundaryId
            states.resetStyle(target)
            map.removeLayer(states)
          else
            states = boundaries
            stateResults = boundaryResults
          
          map.fitBounds(boundaries.getBounds());
          map.on 'resize', (e) ->
            map.fitBounds(boundaries.getBounds())

    info.addTo(map);  
        info.addTo(map);
    info.addTo(map);  
        info.addTo(map);
    info.addTo(map);  
    states = L.geoJson(geojson, { style: countStyle, onEachFeature: onEachFeature })
    states.addTo(map)
    map.fitBounds(states.getBounds());
    
    loadBoundary(url, null, null)
    map

  # fetch our top level states
  $.ajax({url:'/boundaries/', dataType: "json"}).done((states) ->
    # now that we have states, initialize each map
    $(".map").each(->
      url = $(this).data("map-url")
      id = $(this).attr("id")
      districtZoom = $(this).data("district-zoom")
      wardZoom = $(this).data("ward-zoom")

      # no id? can't render, warn in console
      if (id == undefined)
        console.log("missing map id, not rendering")
        return

      # no url? render empty map
      if (url == undefined)
        console.log("missing map url, rendering empty")
        map = L.map(id, options)
        boundaries = L.geoJSON(states, {style: emptyStyle})
        boundaries.addTo(map);
        map.fitBounds(boundaries.getBounds());
        return
      
      map = initMap(id, states, url, districtZoom, wardZoom)

    )
  )
)