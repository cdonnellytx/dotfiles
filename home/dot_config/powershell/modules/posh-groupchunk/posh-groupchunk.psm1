using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Globalization
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Reflection
using namespace System.Text
using namespace System.Xml
using namespace System.Xml.Linq

param()

class GroupInfo
{
    [int] $Count
    [int] $Index
    [PSObject[]] $Group
}

function Group-Chunk
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject] $InputObject,

        [Parameter(Position = 0)]
        [ValidateRange('Positive')]
        [int] $Size = 100,

        [Parameter()]
        [switch] $AsHashtable
    )

    begin
    {
        $buf = [System.Collections.Generic.List[PSObject]]::new($Size)
        [ref] $index = [ref] 0

        $FlushSplat = @{
            Index = $index
            AsHashtable = $AsHashtable
        }

        function Flush([ref] $Index, [bool] $AsHashtable)
        {
            if ($buf.Count -eq 0)
            {
                # Refusing to return an empty group.
                return
            }

            [hashtable] $out = @{
                Count = $buf.Count
                Index = $Index.Value++
                Group = [PSObject[]] $buf
            }

            $buf.Clear()

            if ($AsHashtable)
            {
                return $out
            }

            return [GroupInfo] $out
        }
    }

    process
    {
        $buf.Add($InputObject)
        if ($buf.Count -ge $Size)
        {
            Flush @FlushSplat
        }
    }

    end
    {
        Flush @FlushSplat
    }


}