#requires -version 3.0
<# Param (
	[Parameter(Mandatory=$True)] [string] $srcUrl = "http://es.wikipedia.org/wiki/Mermelada",
	[string] $dstUrl = "http://es.wikipedia.org/wiki/Gelatina"
) 
#>

Param (
	[string] $srcUrl = "http://es.wikipedia.org/wiki/Jalea",
	[string] $dstUrl = "https://es.wikipedia.org/wiki/Cola_de_pescado"
)


# Functions

Function GetIds {
	Param (
		[string] $url
	)
	Write-Host $url
	$html = Invoke-WebRequest -Uri $url
	$currentId = GetId $url
	
	$links = $html.Links.href
	$validLinks = @()
	$cont = 0
	foreach($link in $links) {
		if($link -match "^/wiki/(\w*)$" -And -Not $link.toLower().Contains($currentId) -And -Not $link.EndsWith("Wikimedia_Commons") -And -Not $link.EndsWith("Wikcionario")) {
			$newLink = $matches[1]
			if(-Not $validLinks.Contains($newLink)) {
				$validLinks += $newLink.toLower()
				$cont++
			}
		}
	}

	#Write-Host ( "Cantidad: {0}" -f $cont) # debug
	Return $validLinks
}

# Return the string in a url that it's after the last "/"
# ex: "http://en.wikipedia.org/wiki/jam" => "jam"
Function GetId {
	Param (
		[string] $url
	)
	
	if($url -match "/(\w*)$") {
		Return $matches[1].toLower()
	} else {
		Return $null
	}
}

# Return the language code contained in the url ("es" by default)
# ex: "http://en.wikipedia.org/wiki/jam" => "es"
Function GetLanguage {
	Param (
		[string] $url
	)
	
	if($url -match "//(\w*).wikipedia.org") {
		Return $matches[1].toLower()
	} else {
		Return "es"
	}
}

# Check if a item is contained in a structure of the form:
<# @(
     "term0",
	 @(
	   @(
	     "term00",
		 @(
		   "term000",
		   "term001",
		   "term002"
		   )
	   "term01",
	   "term02"
	 )
  )
#>
Function Contained {
	Param (
		[String] $id,
		[Object[]] $arr
	)
	
	foreach($item in $arr) {

		if($item.getType().name -eq "String") {
			if($item -eq $id) {
				Return $True
			}
		} else {
			if((Contained $id $item)) {
				Return $True
			}
		}
	}
	
	Return $False
}

# Breaks down a level of the structure and return if a link is found
Function BreakDown {
	Param (
		[int] $num,
		[ref] $arr,      # Array to break down
		[string] $idDst  # Array of the other side (src <-> dst)
	)
	
	Write-Host ("Starting {0}..." -f $num)
	
	$arrVal = $arr.Value
	
	if($num -eq 0) {  # @("t0") => @("t0", @("t00", "t01"))
		$url = "http://{0}.wikipedia.org/wiki/{1}" -f $lang, $arr.value[0]
		$arrVal = $arrVal[0],@((GetIds $url))
		foreach($item in $arrVal[1]) {
			If($item -eq $idDst) {
				Write-Host ("Almost done: {0}" -f $item)
				Return $True
			}
		}
	} elseif($num -eq 1) { # @("t0", @("t00", "t01")) => @("t0", @(@("t00", @("t000", "t001")), @("t01", @("t010", "t011"))))
		for($i=0; $i -lt $arrVal[1].Length; $i++) {
			$url = "http://{0}.wikipedia.org/wiki/{1}" -f $lang, $arrVal[1][$i]
			$arrVal[1][$i] = $arrVal[1][$i], @((GetIds $url))
			foreach($item in $arrVal[1][$i][1]) {
				if($item -eq $idDst) {
					Write-Host ("Almost done: {0}" -f $item)
					Return $True
				} #else { Write-Host("{0} <> {1}" -f $item, $idDst) }
			}
			
		}	
	}
	
	$arr.Value = $arrVal
	Return $False
}


Function GetLinkedRoute {
	Param (
		[string] $srcId,
		[string] $dstId,
		[Object[]] $routes
	)
	
	foreach($item in $routes[1]) {
		if($item.getType().name -eq "String") {
			if($item -eq $dstId) {
				return $routes[0], $item
			} #else { Write-Host("{0} <> {1}" -f $item, $dstId) }
		} else {
			$route = GetLinkedRoute $srcId $dstId $item
			if($route) {
				return @($routes[0]) + $route
			}
		}
	}
	
	return $null
}


# Main
$lang = GetLanguage $srcUrl

Write-Host ("Origen: {0}`nDestino: {1}" -f $srcUrl, $dstUrl)

#$src = @((GetId $srcUrl), (GetIds $srcUrl))
#$dst = @((GetId $dstUrl), (GetIds $dstUrl)) 
$srcId = (GetId $srcUrl).toLower()
$dstId = (GetId $dstUrl).toLower()
$routes = @($srcId)

$lvl = 0
$linked = $False
while(-Not $linked -And $lvl -lt 5) {
	$linked = (BreakDown $lvl ([ref]$routes) $dstId)
	$linked
	$lvl++
}

if($linked) {
	$vRoute = GetLinkedRoute $srcId $dstId $routes
	Write-Host ("Link found: {0}" -f ($vRoute -join " -> "))
} else {
	Write-Host ("Link not found ({0} levels)" -f $lvl)
}

$routes.Length


