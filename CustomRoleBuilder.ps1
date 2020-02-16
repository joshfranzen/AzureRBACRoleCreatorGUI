Add-Type -AssemblyName PresentationFramework

function set-azlogincontext {
if (!(get-azcontext)) {

    Login-AzAccount

}
}

function New-CustomRbacRole {





$subscriptionID = (Get-AzSubscription -SubscriptionName $var_Subscription.SelectedItem).id
$resourcegroup = $var_ResourceGroup.SelectedItem

#enter in a useful description. i.e. “Data Factory Contributor, but denies edit/create/delete of Triggers, runtimes, #and pipleines
$role = Get-AzRoleDefinition -name Reader

#blank the id so that it doesn’t overwrite
$Role.id = $null
#set the role name
$Role.Name = $var_RoleName.text
$role.Description = $var_Description.text


#add allowed and not allowed actions
# The actions param cannot be empty, but should have something from the template role allowing creation of the role #without further input


#split data actions and non data actions

    foreach ($perm in $var_SelectedPerms.items) {

        if ((Get-AzProviderOperation -OperationSearchString $perm).IsDataAction -eq $true) {
        $role.dataactions.add("$perm")
        }
        else {
        $role.actions.add("$perm")
        }

    }

$role.AssignableScopes.clear()
if (!($resourcegroup)){
$role.AssignableScopes.add("/subscriptions/$subscriptionID")
}
else{
$role.AssignableScopes.add("/subscriptions/$subscriptionID/resourceGroups/$resourcegroup/")
}
New-AzRoleDefinition -Role $role 
$var_SelectedPerms.Items.Clear()

$rolename = $role.name
}

# where is the XAML file?
$xamlFile = "C:\Users\Josh\Documents\Dev\AzureRBACRoleBuilder\AzureRBACRoleBuilder\MainWindow.xaml"

#create window
$inputXML = Get-Content $xamlFile -Raw
$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$XAML = $inputXML

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $window = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_*


$var_Subscription.ItemsSource = (Get-AzSubscription).Name

$var_Subscription.Add_SelectionChanged( {
   $var_statusout.text="Updating Subscription"
   $var_Resourcegroup.Items.Clear()
   set-azcontext -Subscriptionname $var_Subscription.SelectedItem
   $subscription = (get-azcontext).name.Split()[0]
   $var_Resourcegroup.ItemsSource = (Get-AzResourceGroup).ResourceGroupName
   $var_statusout.text="Subscription changed to $subscription"
   })

$var_ProviderType.ItemsSource = (get-azprovideroperation | select -Unique providernamespace | Where-Object providernamespace -Like "Microsoft*" | sort providernamespace).providernamespace

$var_ProviderType.Add_SelectionChanged( {
   #clear the result box
   $var_statusout.text="Updating Provider list..."
   $var_AvailablePerms.Items.Clear()
   $ProviderSelection = $var_ProviderType.SelectedItem
   $availableperms = (Get-AzProviderOperation | where providernamespace -EQ $ProviderSelection).Operation
        foreach ($perm in $availableperms) {
        $var_AvailablePerms.Items.Add("$perm")   
             }
   $var_statusout.text="Provider type changed to $ProviderSelection"
   })


$var_Add.Add_Click( {
        $addedvalue = $var_AvailablePerms.SelectedItems
        foreach ($perm in $addedvalue) {
        if (!($var_SelectedPerms.items -match $perm)) {
        $var_SelectedPerms.Items.Add("$perm")
        }
        }
   })

$var_Remove.Add_Click( {
        $removedvalue = $var_selectedPerms.SelectedItems
        $var_SelectedPerms.Items.Remove("$removedvalue")

 
   })

$var_Clear.Add_Click( {
        $var_SelectedPerms.Items.Clear() 
   })

$var_Build.Add_Click( {
        New-CustomRbacRole 
        $var_statusout.text="Created $rolename"
   })



$Null = $window.ShowDialog()