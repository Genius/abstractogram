$(function() {
  $("#query-form").on({
    'ajax:error': function() {
      alert("WHOOPS! Something went wrong, try again")
    },
    'ajax:success': function(xhr, data, status) {
      var $this = $(this)
      var query = $this.find("#q").val()
      
      if (history && history.pushState) {
        window.history.pushState(null, null, "/?q=" + encodeURIComponent(query))
      }
      
      $("#graph-container").highcharts({
        series: data.series,
        title: { text: data.title },
        yAxis: {
          min: 0,
          title: { text: "Word Count" },
          allowDecimals: false
        },
        xAxis: {
          allowDecimals: false
        },
        legend: { borderWidth: 0 },
        plotOptions: {
          series: {
            animation: false,
            marker: { enabled: false }
          }
        },
        tooltip: {
          shared: true,
          formatter: function() {
            var s = '<b>' + this.x + '</b>'
            
            var sortedPoints = this.points.sort(function(a, b) {
              return ((a.y < b.y) ? 1 : ((a.y > b.y) ? -1 : 0));
            });
            
            $.each(sortedPoints, function(i, point) {
              s += '<br/><span style="color: ' + point["series"]["color"] + '">' +
                    point.series.name + ':</span> ' + point.y
            });
            return s;
          }
        },
        credits: { enabled: false }
      })
    }
  })
  
  if ($("#q").val()) {
    $("#query-form").submit()
  }
})
