using System;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.VisualStudio.Shell;
using task = System.Threading.Tasks.Task;
using ui = Microsoft.VisualStudio.VSConstants.UICONTEXT;

namespace FileIcons
{
    [Guid(PackageGuids.guidVSPackageString)]
    [PackageRegistration(UseManagedResourcesOnly = true)]
    [InstalledProductRegistration("#110", "#112", Vsix.Version, IconResourceID = 400)]
    [ProvideMenuResource("Menus.ctmenu", 1)]
    [ProvideAutoLoad(LoadContext)]
    [ProvideUIContextRule(LoadContext,
        name: "Auto load",
        expression: "FullyLoaded & (SingleProject | MultipleProjects)",
        termNames: new[] { "FullyLoaded", "SingleProject", "MultipleProjects" },
        termValues: new[] { ui.SolutionExistsAndFullyLoaded_string, ui.SolutionHasSingleProject_string, ui.SolutionHasMultipleProjects_string },
        delay: 500)]

    public sealed class FileIconPackage : AsyncPackage
    {
        private const string LoadContext = "1501ac94-e5fa-4e6b-b780-0959421d99a3";

        protected override async task InitializeAsync(CancellationToken cancellationToken, IProgress<ServiceProgressData> progress)
        {
            await ReportMissingIcon.Initialize(this);
        }
    }
}