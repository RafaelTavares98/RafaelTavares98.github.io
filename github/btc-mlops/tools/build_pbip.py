"""Generate the Power BI project for the MLOps pipeline findings.

Writes a PBIP folder with a TMDL semantic model and a PBIR report. Power BI
Desktop opens the .pbip file directly.
"""
import io, json, os, uuid

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))))), "powerbi", "btc-mlops")
NAME = "btc-mlops"
MODEL = os.path.join(ROOT, f"{NAME}.SemanticModel")
REPORT = os.path.join(ROOT, f"{NAME}.Report")

# The folder holding the CSV files. Set it once in Power BI Desktop, under
# Transform data, Manage parameters. No personal path enters the repository.
DEFAULT_DATA_FOLDER = r"C:\\powerbi\\btc-mlops\\data"

# ---------------------------------------------------------------- palette
BG = "#0F1626"        # page
CARD = "#1A2236"      # tile
INK = "#E8ECF5"       # text
MUTED = "#8A94AD"
BLUE = "#5B8DEF"
TEAL = "#22C1A4"
ORANGE = "#F5A623"
RED = "#EF4B6B"
PURPLE = "#9B6BE8"


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    io.open(path, "w", encoding="utf-8").write(text)


def wjson(path, obj):
    write(path, json.dumps(obj, indent=2))


# ================================================================ the model
TABLES = {
    "Hourly": ["open_time", "actual_range", "predicted_range", "baseline_range",
               "model_error", "baseline_error", "hour_of_day", "date", "model_wins"],
    "Price": ["open_time", "close", "volume", "trades"],
    "KPI": ["measure", "value", "kind"],
    "SkillByHour": ["hour_of_day", "hours", "skill", "avg_actual", "verdict"],
    "Drift": ["feature", "p_value", "verdict", "importance"],
    "TestScore": ["section", "score"],
}
FILES = {"Hourly": "hourly.csv", "Price": "price.csv", "KPI": "kpi.csv",
         "SkillByHour": "skill_by_hour.csv", "Drift": "drift.csv",
         "TestScore": "test_score.csv"}
TYPES = {
    "open_time": "dateTime", "date": "dateTime",
    "measure": "string", "kind": "string", "verdict": "string",
    "feature": "string", "section": "string",
    "hour_of_day": "int64", "hours": "int64", "model_wins": "int64",
    "trades": "int64", "importance": "int64",
}


def tmdl_type(column):
    return TYPES.get(column, "double")


def data_type(column):
    kind = tmdl_type(column)
    return {"dateTime": "dateTime", "string": "string",
            "int64": "int64", "double": "double"}[kind]


def m_type(column):
    return {"dateTime": "type datetime", "string": "type text",
            "int64": "Int64.Type", "double": "type number"}[tmdl_type(column)]


def table_tmdl(name):
    columns = TABLES[name]
    body = [f"table {name}", f"\tlineageTag: {uuid.uuid4()}", ""]
    for column in columns:
        body += [f"\tcolumn {column}",
                 f"\t\tdataType: {data_type(column)}",
                 f"\t\tsourceColumn: {column}",
                 f"\t\tlineageTag: {uuid.uuid4()}",
                 ""]
    changed = ", ".join(f'{{"{c}", {m_type(c)}}}' for c in columns)
    body += [
        f"\tpartition {name} = m",
        "\t\tmode: import",
        "\t\tsource =",
        "\t\t\t\tlet",
        f'\t\t\t\t    Source = Csv.Document(File.Contents(DataFolder & "\\{FILES[name]}"),'
        "[Delimiter=\",\", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),",
        "\t\t\t\t    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),",
        f"\t\t\t\t    Typed = Table.TransformColumnTypes(Headers, {{{changed}}})",
        "\t\t\t\tin",
        "\t\t\t\t    Typed",
        "",
    ]
    return "\n".join(body)


def build_model():
    write(os.path.join(MODEL, ".platform"), json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
        "metadata": {"type": "SemanticModel", "displayName": NAME},
        "config": {"version": "2.0", "logicalId": str(uuid.uuid4())}}, indent=2))

    wjson(os.path.join(MODEL, "definition.pbism"),
          {"version": "4.0", "settings": {}})

    write(os.path.join(MODEL, "definition", "database.tmdl"),
          "database\n\tcompatibilityLevel: 1567\n")

    refs = "\n".join(f"ref table {t}" for t in TABLES)
    write(os.path.join(MODEL, "definition", "model.tmdl"),
          "model Model\n"
          "\tculture: en-US\n"
          "\tdefaultPowerBIDataSourceVersion: powerBI_V3\n"
          "\tsourceQueryCulture: en-US\n"
          "\tdataAccessOptions\n"
          "\t\tlegacyRedirects\n"
          "\t\treturnErrorValuesAsNull\n\n"
          f"{refs}\n\n"
          "ref expression DataFolder\n")

    write(os.path.join(MODEL, "definition", "expressions.tmdl"),
          'expression DataFolder = "'
          + DEFAULT_DATA_FOLDER + '" meta [IsParameterQuery=true, '
          'Type="Text", IsParameterQueryRequired=true]\n'
          f"\tlineageTag: {uuid.uuid4()}\n\n"
          "\tannotation PBI_NavigationStepName = Navigation\n\n"
          "\tannotation PBI_ResultType = Text\n")

    for name in TABLES:
        write(os.path.join(MODEL, "definition", "tables", f"{name}.tmdl"),
              table_tmdl(name))


# =============================================================== the report
def field(table, column, aggregate=None):
    ref = {"Column": {"Expression": {"SourceRef": {"Entity": table}}, "Property": column}}
    if aggregate:
        ref = {"Aggregation": {"Expression": ref, "Function": aggregate}}
    return ref


def projection(table, column, name, aggregate=None):
    return {"field": field(table, column, aggregate), "queryRef": name, "nativeQueryRef": name}


def visual(vid, x, y, w, h, vtype, projections, objects=None, z=0, title=None):
    query = {"queryState": {}}
    for role, items in projections.items():
        query["queryState"][role] = {"projections": items}
    config = {
        "name": vid,
        "layouts": [{"id": 0, "position": {"x": x, "y": y, "z": z,
                                           "width": w, "height": h,
                                           "tabOrder": z * 100}}],
        "visual": {"visualType": vtype, "query": query,
                   "objects": objects or {}, "drillFilterOtherVisuals": True},
    }
    if title:
        config["visual"]["objects"].setdefault("title", [{
            "properties": {"text": {"expr": {"Literal": {"Value": f"'{title}'"}}},
                           "fontColor": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{INK}'"}}}}},
                           "fontSize": {"expr": {"Literal": {"Value": "13D"}}},
                           "bold": {"expr": {"Literal": {"Value": "true"}}},
                           "show": {"expr": {"Literal": {"Value": "true"}}}}}])
    config["visual"]["objects"].setdefault("background", [{
        "properties": {"color": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{CARD}'"}}}}},
                       "show": {"expr": {"Literal": {"Value": "true"}}}}}])
    config["visual"]["visualContainerObjects"] = {
        "background": [{"properties": {
            "color": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{CARD}'"}}}}},
            "show": {"expr": {"Literal": {"Value": "true"}}},
            "transparency": {"expr": {"Literal": {"Value": "0D"}}}}}],
        "border": [{"properties": {
            "show": {"expr": {"Literal": {"Value": "true"}}},
            "color": {"solid": {"color": {"expr": {"Literal": {"Value": "'#252E45'"}}}}},
            "radius": {"expr": {"Literal": {"Value": "12D"}}}}}],
    }
    return {"$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/1.4.0/schema.json",
            **config}


def textbox(vid, x, y, w, h, runs, z=0, transparent=True):
    paragraphs = [{"textRuns": runs}]
    config = {
        "name": vid,
        "layouts": [{"id": 0, "position": {"x": x, "y": y, "z": z, "width": w,
                                           "height": h, "tabOrder": z * 100}}],
        "visual": {"visualType": "textbox",
                   "objects": {"general": [{"properties": {
                       "paragraphs": paragraphs}}]},
                   "drillFilterOtherVisuals": True},
        "visualContainerObjects": {"background": [{"properties": {
            "show": {"expr": {"Literal": {"Value": "false" if transparent else "true"}}}}}]},
    }
    return {"$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/1.4.0/schema.json",
            **config}


def run(text, size=12, color=INK, bold=False):
    return {"value": text, "textStyle": {"fontSize": f"{size}pt", "color": color,
                                         "fontWeight": "bold" if bold else "normal",
                                         "fontFamily": "Segoe UI"}}


def data_colors(color):
    return {"dataPoint": [{"properties": {"fill": {"solid": {"color": {
        "expr": {"Literal": {"Value": f"'{color}'"}}}}}}}]}


def build_report():
    write(os.path.join(REPORT, ".platform"), json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
        "metadata": {"type": "Report", "displayName": NAME},
        "config": {"version": "2.0", "logicalId": str(uuid.uuid4())}}, indent=2))

    wjson(os.path.join(REPORT, "definition.pbir"), {
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/1.0.0/schema.json",
        "version": "4.0",
        "datasetReference": {"byPath": {"path": f"../{NAME}.SemanticModel"}}})

    wjson(os.path.join(REPORT, "definition", "version.json"),
          {"$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/versionMetadata/1.0.0/schema.json",
           "version": "2.0.0"})

    wjson(os.path.join(REPORT, "definition", "report.json"), {
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/2.0.0/schema.json",
        "themeCollection": {"customTheme": {"name": "MLOpsDark", "type": "RegisteredResources"}},
        "resourcePackages": [{"name": "RegisteredResources", "type": "RegisteredResources",
                              "items": [{"name": "MLOpsDark", "path": "MLOpsDark.json",
                                         "type": "CustomTheme"}]}],
        "settings": {"useStylableVisualContainerHeader": True,
                     "defaultDrillFilterOtherVisuals": True},
    })

    wjson(os.path.join(REPORT, "StaticResources", "RegisteredResources", "MLOpsDark.json"), {
        "name": "MLOpsDark",
        "background": BG, "foreground": INK, "tableAccent": BLUE,
        "dataColors": [BLUE, TEAL, ORANGE, PURPLE, RED, MUTED],
        "good": TEAL, "neutral": ORANGE, "bad": RED,
        "textClasses": {
            "title": {"fontFace": "Segoe UI", "fontSize": 14, "color": INK},
            "label": {"fontFace": "Segoe UI", "fontSize": 10, "color": MUTED},
            "callout": {"fontFace": "Segoe UI", "fontSize": 32, "color": INK},
        },
        "visualStyles": {"*": {"*": {
            "background": [{"color": {"solid": {"color": CARD}}, "show": True, "transparency": 0}],
            "border": [{"show": True, "color": {"solid": {"color": "#252E45"}}, "radius": 12}],
            "title": [{"show": True, "fontColor": {"solid": {"color": INK}},
                       "background": {"solid": {"color": CARD}}, "fontSize": 12, "bold": True}],
            "labels": [{"color": {"solid": {"color": MUTED}}, "fontSize": 9}],
            "categoryAxis": [{"labelColor": {"solid": {"color": MUTED}},
                              "gridlineShow": False, "fontSize": 9}],
            "valueAxis": [{"labelColor": {"solid": {"color": MUTED}},
                           "gridlineColor": {"solid": {"color": "#252E45"}}, "fontSize": 9}],
            "legend": [{"labelColor": {"solid": {"color": MUTED}}, "fontSize": 9}],
        }}},
    })

    pages = [overview_page(), quality_page()]
    wjson(os.path.join(REPORT, "definition", "pages", "pages.json"), {
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.0.0/schema.json",
        "pageOrder": [p["name"] for p in pages],
        "activePageName": pages[0]["name"]})

    for page in pages:
        folder = os.path.join(REPORT, "definition", "pages", page["name"])
        visuals = page.pop("visuals")
        wjson(os.path.join(folder, "page.json"), page)
        for v in visuals:
            wjson(os.path.join(folder, "visuals", v["name"], "visual.json"), v)


def page_shell(name, display):
    return {"$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.0.0/schema.json",
            "name": name, "displayName": display,
            "displayOption": "FitToPage", "height": 720, "width": 1280,
            "objects": {"background": [{"properties": {
                "color": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{BG}'"}}}}},
                "transparency": {"expr": {"Literal": {"Value": "0D"}}}}}],
                "outspace": [{"properties": {
                    "color": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{BG}'"}}}}}}}]}}


def kpi_tile(vid, x, y, w, h, table, column, title, color, aggregate="Sum"):
    objects = {
        "labels": [{"properties": {
            "color": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{color}'"}}}}},
            "fontSize": {"expr": {"Literal": {"Value": "28D"}}},
            "bold": {"expr": {"Literal": {"Value": "true"}}}}}],
        "categoryLabels": [{"properties": {
            "show": {"expr": {"Literal": {"Value": "false"}}}}}],
    }
    return visual(vid, x, y, w, h, "card",
                  {"Values": [projection(table, column, f"{aggregate}({table}.{column})", aggregate)]},
                  objects, title=title)


def overview_page():
    name = "PageOverview"
    v = []

    v.append(textbox("titleMain", 24, 20, 620, 60, [
        run("MLOps Pipeline", 24, INK, True),
        run("   Bitcoin hourly volatility", 13, MUTED)]))
    v.append(textbox("titleSub", 24, 66, 700, 30, [
        run("Continuous training, a promotion gate, and drift monitoring. "
            "The subject is small on purpose.", 10, MUTED)]))

    v.append(kpi_tile("kpiSkill", 24, 110, 240, 130, "Hourly", "model_wins",
                      "Hours the model wins", TEAL))
    v.append(visual("kpiMae", 280, 110, 240, 130, "card",
                    {"Values": [projection("Hourly", "model_error",
                                           "Average(Hourly.model_error)", "Avg")]},
                    {"labels": [{"properties": {
                        "color": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{BLUE}'"}}}}},
                        "fontSize": {"expr": {"Literal": {"Value": "26D"}}},
                        "bold": {"expr": {"Literal": {"Value": "true"}}}}}],
                     "categoryLabels": [{"properties": {"show": {"expr": {"Literal": {"Value": "false"}}}}}]},
                    title="Model error, mean absolute"))
    v.append(visual("kpiBase", 536, 110, 240, 130, "card",
                    {"Values": [projection("Hourly", "baseline_error",
                                           "Average(Hourly.baseline_error)", "Avg")]},
                    {"labels": [{"properties": {
                        "color": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{ORANGE}'"}}}}},
                        "fontSize": {"expr": {"Literal": {"Value": "26D"}}},
                        "bold": {"expr": {"Literal": {"Value": "true"}}}}}],
                     "categoryLabels": [{"properties": {"show": {"expr": {"Literal": {"Value": "false"}}}}}]},
                    title="Baseline error, mean absolute"))
    v.append(visual("kpiHours", 792, 110, 220, 130, "card",
                    {"Values": [projection("Hourly", "actual_range",
                                           "CountNonNull(Hourly.actual_range)", "CountNotNull")]},
                    {"labels": [{"properties": {
                        "color": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{INK}'"}}}}},
                        "fontSize": {"expr": {"Literal": {"Value": "26D"}}},
                        "bold": {"expr": {"Literal": {"Value": "true"}}}}}],
                     "categoryLabels": [{"properties": {"show": {"expr": {"Literal": {"Value": "false"}}}}}]},
                    title="Hours scored"))
    v.append(visual("kpiScore", 1028, 110, 228, 130, "card",
                    {"Values": [projection("TestScore", "score", "Min(TestScore.score)", "Min")]},
                    {"labels": [{"properties": {
                        "color": {"solid": {"color": {"expr": {"Literal": {"Value": f"'{PURPLE}'"}}}}},
                        "fontSize": {"expr": {"Literal": {"Value": "26D"}}},
                        "bold": {"expr": {"Literal": {"Value": "true"}}}}}],
                     "categoryLabels": [{"properties": {"show": {"expr": {"Literal": {"Value": "false"}}}}}]},
                    title="ML Test Score, the minimum"))

    v.append(visual("chartForecast", 24, 256, 752, 250, "lineChart",
                    {"Category": [projection("Hourly", "open_time", "Hourly.open_time")],
                     "Y": [projection("Hourly", "actual_range", "Sum(Hourly.actual_range)", "Sum"),
                           projection("Hourly", "predicted_range", "Sum(Hourly.predicted_range)", "Sum")]},
                    {"legend": [{"properties": {"position": {"expr": {"Literal": {"Value": "'TopRight'"}}}}}]},
                    title="Predicted against actual, hour by hour"))

    v.append(visual("chartHour", 792, 256, 464, 250, "columnChart",
                    {"Category": [projection("SkillByHour", "hour_of_day", "SkillByHour.hour_of_day")],
                     "Y": [projection("SkillByHour", "skill", "Sum(SkillByHour.skill)", "Sum")]},
                    data_colors(TEAL),
                    title="Skill by hour of day. Two hours are negative"))

    v.append(visual("chartPrice", 24, 522, 496, 180, "areaChart",
                    {"Category": [projection("Price", "open_time", "Price.open_time")],
                     "Y": [projection("Price", "close", "Sum(Price.close)", "Sum")]},
                    data_colors(BLUE), title="BTCUSDT close, last 720 hours"))

    v.append(visual("chartVolume", 536, 522, 240, 180, "donutChart",
                    {"Category": [projection("SkillByHour", "verdict", "SkillByHour.verdict")],
                     "Y": [projection("SkillByHour", "hours", "Sum(SkillByHour.hours)", "Sum")]},
                    {}, title="Hours by verdict"))

    v.append(visual("tableDrift", 792, 522, 464, 180, "tableEx",
                    {"Values": [projection("Drift", "feature", "Drift.feature"),
                                projection("Drift", "verdict", "Drift.verdict"),
                                projection("Drift", "importance", "Sum(Drift.importance)", "Sum")]},
                    {}, title="Drift and importance, by feature"))

    page = page_shell(name, "Overview")
    page["visuals"] = v
    return page


def quality_page():
    name = "PageQuality"
    v = []
    v.append(textbox("qTitle", 24, 20, 700, 50, [
        run("Production readiness", 22, INK, True),
        run("   the ML Test Score, section by section", 12, MUTED)]))

    v.append(visual("scoreBars", 24, 90, 600, 300, "barChart",
                    {"Category": [projection("TestScore", "section", "TestScore.section")],
                     "Y": [projection("TestScore", "score", "Sum(TestScore.score)", "Sum")]},
                    data_colors(PURPLE),
                    title="Score by section. The final score is the minimum"))

    v.append(visual("kpiTable", 640, 90, 616, 300, "tableEx",
                    {"Values": [projection("KPI", "measure", "KPI.measure"),
                                projection("KPI", "value", "Sum(KPI.value)", "Sum")]},
                    {}, title="The numbers the pipeline reported"))

    v.append(visual("errorScatter", 24, 410, 600, 290, "scatterChart",
                    {"X": [projection("Hourly", "baseline_error", "Sum(Hourly.baseline_error)", "Sum")],
                     "Y": [projection("Hourly", "model_error", "Sum(Hourly.model_error)", "Sum")],
                     "Details": [projection("Hourly", "open_time", "Hourly.open_time")]},
                    data_colors(BLUE),
                    title="Model error against baseline error, one point per hour"))

    v.append(visual("driftBars", 640, 410, 616, 290, "barChart",
                    {"Category": [projection("Drift", "feature", "Drift.feature")],
                     "Y": [projection("Drift", "importance", "Sum(Drift.importance)", "Sum")]},
                    data_colors(TEAL), title="Feature importance"))

    page = page_shell(name, "Quality")
    page["visuals"] = v
    return page


# ================================================================= the file
def build_pbip():
    wjson(os.path.join(ROOT, f"{NAME}.pbip"), {
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/pbip/definitionProperties/1.0.0/schema.json",
        "version": "1.0",
        "artifacts": [{"report": {"path": f"{NAME}.Report"}}],
        "settings": {"enableAutoRecovery": True}})

    write(os.path.join(ROOT, ".gitignore"), ".pbi/\n*.pbix\n")


build_model()
build_report()
build_pbip()

for base, _, files in os.walk(ROOT):
    for f in sorted(files):
        print(os.path.relpath(os.path.join(base, f), ROOT))
