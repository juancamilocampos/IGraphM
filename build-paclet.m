(* ::Package:: *)

(* Mathematica Source File  *)
(* Created by Mathematica Plugin for IntelliJ IDEA *)
(* :Author: szhorvat *)
(* :Date: 2016-12-02 *)


$appName = "IGraphM";
$LTemplateRepo = "~/Repos/LTemplate";


printAbort[str_] := (Print["ABORTING: ", Style[str, Red, Bold]]; Quit[])
If[$VersionNumber < 10.0, printAbort["Mathematica 10.0 or later required."]]


$dir =
    Which[
      $InputFileName =!= "", DirectoryName[$InputFileName],
      $Notebooks, NotebookDirectory[],
      True, printAbort["Cannot determine script directory."]
    ]


rg = RunProcess[{"git", "--version"}];
If[rg === $Failed || rg["ExitCode"] != 0,
  printAbort["git is not available."]
]


SetDirectory[$dir]


$buildDir = FileNameJoin[{$dir, "release"}]


If[DirectoryQ[$buildDir],
  Print["Deleting release directory."];
  DeleteDirectory[$buildDir, DeleteContents->True]
]


$appSource = FileNameJoin[{$dir, $appName}]
$appTarget = FileNameJoin[{$buildDir, $appName}]


CreateDirectory[$appTarget, CreateIntermediateDirectories->True]


Print["git-archive IGraphM"]


$gitArch = FileNameJoin[{$buildDir, $appName<>".tar"}]


RunProcess[{"git", "archive", "--format", "tar", "-o", $gitArch, "HEAD:IGraphM"}]


ExtractArchive[$gitArch, $appTarget]
DeleteFile[$gitArch]


SetDirectory[$appTarget]


Print["Loading IGraphM paclet..."]
PacletDirectoryAdd[$dir]
Needs[$appName <> "`"]


source = Import["IGraphM.m", "String"];


igDataCompletionRepl = StringTemplate["addCompletion[IGData, ``];"]@
    ToString[{Join[Keys[IGraphM`Private`$igDataCategories],
      Select[Keys[IGraphM`Private`$igData], StringQ]]},
      InputForm
    ]

repl = {
  "Get[\"LTemplate`LTemplatePrivate`\"]" -> "Get[\"IGraphM`LTemplate`LTemplatePrivate`\"]",
  "\"LazyLoading\" -> False" -> "\"LazyLoading\" -> True",
  "addCompletion[IGData, {Join[Keys[$igDataCategories], Select[Keys[$igData], StringQ]]}];" -> igDataCompletionRepl
};


source = StringReplace[source, repl, Length[repl]];


template = StringTemplate[source, Delimiters -> {"%%", "%%", "<%", "%>"}];


versionData = <|
  "version" -> Lookup[PacletInformation[$appName], "Version"],
  "mathversion" -> Lookup[PacletInformation[$appName], "WolframVersion"],
  "date" -> DateString[{"MonthName", " ", "DayShort", ", ", "Year"}]
|>


source = template[versionData];


Export[FileNameJoin[{$appTarget, "IGraphM.m"}], source, "String"]

Print["\nRe-encoding source files as ASCII"]
AddPath["PackageTools"]
Needs["PackageTools`"]
With[{$appTarget = $appTarget},
  MRun[
    MCode[
      UsingFrontEnd[
        NotebookSave@NotebookOpen[FileNameJoin[{$appTarget, #}]]& /@
            {"IGraphM.m", "PacletInfo.m", "Common.m", "Utilities.m"}
      ]
    ]
  ]
]

DeleteFile["BuildSettings.m"]


(***** Copy LTemplate *****)

Print["\ngit-archive LTemplate"]

SetDirectory@CreateDirectory["LTemplate"]

RunProcess[{"git", "archive", "--format", "tar", "-o", "LTemplate.tar", "HEAD:LTemplate", "--remote=" <> $LTemplateRepo}]

ExtractArchive["LTemplate.tar"]

DeleteDirectory["Documentation", DeleteContents -> True]
DeleteFile[{"IncludeFiles/Doxyfile", "LTemplate.tar"}]

ResetDirectory[] (* LTemplate *)


(***** Clean up documentation *****)

Print["\nProcessing documentation."]
SetDirectory@FileNameJoin[{"Documentation", "English"}]

Print["Evaluating..."]
With[{$buildDir = $buildDir},
  MRun[
    MCode[
      PacletDirectoryAdd[$buildDir];
      SetOptions[First[$Output], FormatType -> StandardForm];
      RewriteNotebook[
        NBFEProcess[NotebookEvaluate[#, InsertResults -> True]&]
      ]["IGDocumentation.nb"]
    ],
    (* Note 1: 10.0 can't evaluate from a MathLink-controlled kernel due to a bug, use newer version *)
    (* Note 2: Use 10.4, which supports PlotTheme. *)
    "10.4"
  ]
]

Print["Rewriting..."]

taggingRules = {
  "ModificationHighlight" -> False,
  "ColorType" -> "GuideColor",
  "Metadata" -> {
    "built" -> ToString@DateList[],
  (* "history" -> {"0.3.0", "", "", ""}, *)
    "context" -> $appName <> "`",
    "keywords" -> {"igraph", "IGraph/M", "IGraphM"},
    "specialkeywords" -> {},
    "tutorialcollectionlinks" -> {},
    "index" -> True,
    "label" -> "IGraph/M Guide",
    "language" -> "en",
    "paclet" -> $appName,
    "status" -> "None",
    "summary" -> "IGraph/M is the igraph interface for Mathematica.",
    "synonyms" -> {},
    "tabletags" -> {},
    "title" -> "IGraph/M",
    "titlemodifier" -> "",
    "windowtitle" -> "IGraph/M Documentation",
    "type" -> "Guide",
    "uri" -> "IGraphM/IGDocumentation"}
};

With[{taggingRules = taggingRules},
  MRun[
    MCode[
      RewriteNotebook[
        NBSetOptions[TaggingRules -> taggingRules] /*
            NBSetOptions[Saveable -> False] /*
            NBRemoveChangeTimes /*
            NBResetWindow /*
            NBDisableSpellCheck /*
            NBDeleteOutputByTag /*
            NBDeleteCellTags["DeleteOutput"] /*
            NBRemoveOptions[{PrivateNotebookOptions, Visible, ShowCellTags}] /*
            NBSetOptions[StyleDefinitions -> NBImport["Stylesheet.nb"]]
      ]["IGDocumentation.nb"];
    ],
    "10.0" (* compatibility with 10.0 *)
  ]
]

DeleteFile["Stylesheet.nb"]

Print["Indexing..."]
Needs["DocumentationSearch`"]
indexDir = CreateDirectory["Index"];
ind = NewDocumentationNotebookIndexer[indexDir];
AddDocumentationNotebook[ind, "IGDocumentation.nb"];
CloseDocumentationNotebookIndexer[ind];

ResetDirectory[] (* Documentation *)


ResetDirectory[] (* $appTarget *)

Print["\nPacking paclet..."]
PackPaclet[$appTarget]


Print["\nFinished.\n"]


ResetDirectory[] (* $dir *)
