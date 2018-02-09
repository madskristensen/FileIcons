using System;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.VisualStudio.Shell;
using task = System.Threading.Tasks.Task;
using ui = Microsoft.VisualStudio.VSConstants.UICONTEXT;

[assembly: ProvideCodeBase(AssemblyName = "FileIcons")]

namespace FileIcons
{
    [Guid(PackageGuids.guidVSPackageString)]
    [PackageRegistration(UseManagedResourcesOnly = true, AllowsBackgroundLoading = true)]
    [InstalledProductRegistration("#110", "#112", Vsix.Version, IconResourceID = 400)]
    [ProvideMenuResource("Menus.ctmenu", 1)]
    [ProvideAutoLoad(LoadContext, PackageAutoLoadFlags.BackgroundLoad)]
    [ProvideUIContextRule(LoadContext,
        name: "Auto load",
        expression: "HasDot & FullyLoaded & (SingleProject | MultipleProjects)",
        termNames: new[] { "HasDot", "FullyLoaded", "SingleProject", "MultipleProjects" },
        termValues: new[] { "HierSingleSelectionName:\\.(.+)$", ui.SolutionExistsAndFullyLoaded_string, ui.SolutionHasSingleProject_string, ui.SolutionHasMultipleProjects_string })]

    public sealed class FileIconPackage : AsyncPackage
    {
        private const string LoadContext = "1501ac94-e5fa-4e6b-b780-0959421d99a3";

        protected override async task InitializeAsync(CancellationToken cancellationToken, IProgress<ServiceProgressData> progress)
        {
            await JoinableTaskFactory.SwitchToMainThreadAsync(cancellationToken);

            await ReportMissingIcon.Initialize(this);
        }
    }
}