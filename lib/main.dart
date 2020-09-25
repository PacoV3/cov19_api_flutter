import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

Future<DateDataList> fetchDateDataList(String country) async {
  final response = await http.get('https://api.covid19api.com/dayone/country/' +
      country +
      '/status/confirmed');

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return DateDataList.fromJson(json.decode(response.body));
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load data');
  }
}

Future<CountryList> fetchCountryList() async {
  final response = await http.get('https://api.covid19api.com/countries');

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return CountryList.fromJson(json.decode(response.body));
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load the countries');
  }
}

class CountryList {
  final List<CountryData> countryList;
  final List<DropdownMenuItem<CountryData>> items;

  CountryList({this.countryList, this.items});

  factory CountryList.fromJson(List<dynamic> parsedJson) {
    List<CountryData> countryList = new List<CountryData>();
    List<DropdownMenuItem<CountryData>> items = new List();
    countryList = parsedJson.map((i) => CountryData.fromJson(i)).toList();

    for (CountryData country in countryList) {
      items.add(DropdownMenuItem(
        value: country,
        child: Text(country.country),
      ));
    }

    items.sort((a, b) => (a.value.country).compareTo(b.value.country));

    return new CountryList(countryList: countryList, items: items);
  }
}

class CountryData {
  final String country;
  final String slug;
  final String iso2;

  CountryData({
    this.country,
    this.slug,
    this.iso2,
  });

  factory CountryData.fromJson(Map<String, dynamic> json) {
    return new CountryData(
      country: json['Country'],
      slug: json['Slug'],
      iso2: json['ISO2'],
    );
  }
}

class DateDataList {
  final List<DateData> dateDataList;

  DateDataList({
    this.dateDataList,
  });

  factory DateDataList.fromJson(List<dynamic> parsedJson) {
    List<DateData> dateDataList = new List<DateData>();
    dateDataList = parsedJson.map((i) => DateData.fromJson(i)).toList();
    return new DateDataList(
      dateDataList: dateDataList,
    );
  }
}

class DateData {
  final String country;
  final String countryCode;
  final String status;
  final String date;
  final int cases;

  DateData({
    this.country,
    this.countryCode,
    this.status,
    this.date,
    this.cases,
  });

  factory DateData.fromJson(Map<String, dynamic> json) {
    return new DateData(
      country: json['Country'],
      countryCode: json['CountryCode'],
      status: json['Status'],
      date: json['Date'],
      cases: json['Cases'],
    );
  }
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Datos de Covid'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<DateDataList> dateDataList;
  Future<CountryList> countryList;
  CountryData _selectedCountry;

  @override
  void initState() {
    super.initState();
    countryList = fetchCountryList();
  }

  void onChangeDropDownItem(CountryData selectedCountry) {
    setState(() {
      _selectedCountry = selectedCountry;
      dateDataList = fetchDateDataList(_selectedCountry.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
          child: ListView(
        children: [
          FutureBuilder<CountryList>(
            future: countryList,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Container(
                    padding: EdgeInsets.only(top: 10),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Elige un país: "),
                          DropdownButton(
                            items: snapshot.data.items,
                            value: _selectedCountry,
                            onChanged: onChangeDropDownItem,
                          ),
                        ]));
              } else if (snapshot.hasError) {
                return Text("${snapshot.error}");
              }
              return SizedBox(child: CircularProgressIndicator(), height: 400);
            },
          ),
          FutureBuilder<DateDataList>(
            future: dateDataList,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Container(
                  child: SimpleTimeSeriesChart.withGraphData(
                      snapshot.data.dateDataList),
                  height: 700,
                );
              } else if (snapshot.hasError) {
                return Text("${snapshot.error}");
              }
              return SizedBox(child: CircularProgressIndicator(), height: 400);
            },
          ),
        ],
      )),
    );
  }
}

class SimpleTimeSeriesChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  SimpleTimeSeriesChart(this.seriesList, {this.animate});

  /// Creates a [TimeSeriesChart] with sample data and no transition.
  factory SimpleTimeSeriesChart.withGraphData(List<DateData> dateDataList) {
    return new SimpleTimeSeriesChart(
      _createGraphData(dateDataList),
      // Disable animations for image tests.
      animate: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new charts.TimeSeriesChart(
      seriesList,
      animate: animate,
      // Optionally pass in a [DateTimeFactory] used by the chart. The factory
      // should create the same type of [DateTime] as the data provided. If none
      // specified, the default creates local date time.
      dateTimeFactory: const charts.LocalDateTimeFactory(),
    );
  }

  /// Create one series with sample hard coded data.
  static List<charts.Series<TimeSeriesCases, DateTime>> _createGraphData(
      List<DateData> dateDataList) {
    final List<TimeSeriesCases> data = [];

    for (var i = 0; i < dateDataList.length; i++) {
      DateTime date = DateTime.parse(dateDataList[i].date);
      data.add(new TimeSeriesCases(date, dateDataList[i].cases));
    }

    return [
      new charts.Series<TimeSeriesCases, DateTime>(
        id: 'Cases',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (TimeSeriesCases cases, _) => cases.time,
        measureFn: (TimeSeriesCases cases, _) => cases.cases,
        data: data,
      )
    ];
  }
}

/// Sample time series data type.
class TimeSeriesCases {
  final DateTime time;
  final int cases;

  TimeSeriesCases(this.time, this.cases);
}
