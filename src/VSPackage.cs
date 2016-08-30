using System;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio.Shell.Interop;

namespace FileIcons
{
    [Guid(PackageGuids.guidVSPackageString)]
    [PackageRegistration(UseManagedResourcesOnly = true)]
    [InstalledProductRegistration("#110", "#112", Vsix.Version, IconResourceID = 400)]
    [ProvideAutoLoad(UIContextGuids.SolutionHasSingleProject)]
    [ProvideAutoLoad(UIContextGuids.SolutionHasMultipleProjects)]
    [ProvideMenuResource("Menus.ctmenu", 1)]
    public sealed class FileIconPackage : AsyncPackage
    {
        protected override async System.Threading.Tasks.Task InitializeAsync(CancellationToken cancellationToken, IProgress<ServiceProgressData> progress)
        {
            await ReportMissingIcon.Initialize(this);
        }
    }
}