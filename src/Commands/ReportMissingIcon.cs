using System;
using System.Collections.Generic;
using System.ComponentModel.Design;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Microsoft.VisualStudio;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio.Shell.Interop;

namespace FileIcons
{
    internal sealed class ReportMissingIcon
    {
        private const string _urlFormat = "https://github.com/madskristensen/FileIcons/issues/new?template=icon_request.yml&title={0}";
        private const string _logSource = nameof(FileIcons);

        private readonly AsyncPackage _package;
        private HashSet<string> _shellExtensions;
        private string _ext;

        private ReportMissingIcon(AsyncPackage package, OleMenuCommandService commandService)
        {
            _package = package ?? throw new ArgumentNullException(nameof(package));
            commandService = commandService ?? throw new ArgumentNullException(nameof(commandService));

            var id = new CommandID(PackageGuids.guidVSPackageCmdSet, PackageIds.ReportMissingIconId);
            var command = new OleMenuCommand(Execute, id);
            command.BeforeQueryStatus += BeforeQueryStatus;
            commandService.AddCommand(command);
        }

        public static ReportMissingIcon Instance { get; private set; }

        public static async Task InitializeAsync(AsyncPackage package)
        {
            if (package == null)
            {
                throw new ArgumentNullException(nameof(package));
            }

            await ThreadHelper.JoinableTaskFactory.SwitchToMainThreadAsync(package.DisposalToken);
            var commandService = await package.GetServiceAsync(typeof(IMenuCommandService)) as OleMenuCommandService;
            if (commandService == null)
            {
                throw new InvalidOperationException("The Visual Studio command service is unavailable.");
            }

            Instance = new ReportMissingIcon(package, commandService);
        }

        private void BeforeQueryStatus(object sender, EventArgs e)
        {
            ThreadHelper.ThrowIfNotOnUIThread();

            var button = (OleMenuCommand)sender;
            button.Enabled = button.Visible = false;
            _ext = null;

            try
            {
                var filePath = GetSelectedFilePath();
                if (!string.IsNullOrEmpty(filePath))
                {
                    _ext = Path.GetExtension(filePath);
                    var isIconMissing = IsIconMissing(_ext);

                    button.Text = $"Report missing icon for {_ext} files...";
                    button.Enabled = button.Visible = isIconMissing;
                }
            }
            catch (Exception ex)
            {
                ActivityLog.LogError(_logSource, ex.ToString());
            }
        }

        private void Execute(object sender, EventArgs e)
        {
            ThreadHelper.ThrowIfNotOnUIThread();

            if (string.IsNullOrWhiteSpace(_ext))
            {
                throw new InvalidOperationException("No file extension is selected.");
            }

            var title = Uri.EscapeDataString($"Missing icon for {_ext} files");
            VsShellUtilities.OpenSystemBrowser(string.Format(_urlFormat, title));
        }

        private bool IsIconMissing(string fileExtension)
        {
            // Icons can't be associated with extensionless files
            if (string.IsNullOrWhiteSpace(fileExtension))
            {
                return false;
            }

            if (_shellExtensions == null)
            {
                using (var key = _package.ApplicationRegistryRoot.OpenSubKey("ShellFileAssociations"))
                {
                    if (key == null)
                    {
                        throw new InvalidOperationException("The ShellFileAssociations registry key is unavailable.");
                    }

                    _shellExtensions = new HashSet<string>(key.GetSubKeyNames(), StringComparer.OrdinalIgnoreCase);
                }
            }

            return !_shellExtensions.Contains(fileExtension);
        }

        private static string GetSelectedFilePath()
        {
            ThreadHelper.ThrowIfNotOnUIThread();

            var monitorSelection = Package.GetGlobalService(typeof(SVsShellMonitorSelection)) as IVsMonitorSelection;
            if (monitorSelection == null)
            {
                throw new InvalidOperationException("The Visual Studio selection service is unavailable.");
            }

            IntPtr hierarchyPointer = IntPtr.Zero;
            IntPtr selectionContainerPointer = IntPtr.Zero;

            try
            {
                ErrorHandler.ThrowOnFailure(monitorSelection.GetCurrentSelection(
                    out hierarchyPointer,
                    out var itemId,
                    out var multiItemSelect,
                    out selectionContainerPointer));

                if (hierarchyPointer == IntPtr.Zero ||
                    multiItemSelect != null ||
                    itemId == Microsoft.VisualStudio.VSConstants.VSITEMID_NIL)
                {
                    return null;
                }

                var selectedHierarchy = (IVsHierarchy)Marshal.GetTypedObjectForIUnknown(
                    hierarchyPointer,
                    typeof(IVsHierarchy));
                ErrorHandler.ThrowOnFailure(selectedHierarchy.GetCanonicalName(itemId, out var document));
                return document;
            }
            finally
            {
                if (hierarchyPointer != IntPtr.Zero)
                {
                    Marshal.Release(hierarchyPointer);
                }

                if (selectionContainerPointer != IntPtr.Zero)
                {
                    Marshal.Release(selectionContainerPointer);
                }
            }
        }
    }
}
