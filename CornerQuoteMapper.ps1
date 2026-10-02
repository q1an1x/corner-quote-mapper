# Corner Quote Mapper - maps Chinese-mode double quotes to corner quotes.
# Copyright (c) 2026 q1an1x
# SPDX-License-Identifier: MIT
#requires -Version 5.1
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$source = @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace CodexCornerQuotes
{
    public sealed class TrayApplication : ApplicationContext
    {
        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100;
        private const int WM_KEYUP = 0x0101;
        private const int WM_SYSKEYDOWN = 0x0104;
        private const int WM_SYSKEYUP = 0x0105;
        private const int VK_SHIFT = 0x10;
        private const int VK_CONTROL = 0x11;
        private const int VK_MENU = 0x12;
        private const int VK_LWIN = 0x5B;
        private const int VK_RWIN = 0x5C;
        private const uint VK_OEM_7 = 0xDE;
        private const uint LLKHF_INJECTED = 0x10;
        private const uint IME_CMODE_NATIVE = 0x0001;
        private const uint WM_IME_CONTROL = 0x0283;
        private const int IMC_GETCONVERSIONMODE = 0x0001;
        private const int IMC_GETOPENSTATUS = 0x0005;
        private const uint SMTO_ABORTIFHUNG = 0x0002;
        private const uint INPUT_KEYBOARD = 1;
        private const uint KEYEVENTF_KEYUP = 0x0002;
        private const uint KEYEVENTF_UNICODE = 0x0004;

        private readonly LowLevelKeyboardProc hookProc;
        private readonly NotifyIcon trayIcon;
        private readonly ToolStripMenuItem enabledItem;
        private readonly ContextMenuStrip menu;
        private IntPtr hookHandle;
        private bool mappingEnabled = true;
        private bool nextOpening = true;
        private bool quoteKeyHeld;
        private bool suppressQuoteRelease;
        private IntPtr lastForegroundWindow;

        private TrayApplication()
        {
            menu = new ContextMenuStrip();
            enabledItem = new ToolStripMenuItem("\u542f\u7528\u76f4\u89d2\u5f15\u53f7\u6620\u5c04")
            {
                Checked = true,
                CheckOnClick = true
            };
            enabledItem.CheckedChanged += delegate
            {
                mappingEnabled = enabledItem.Checked;
                if (!mappingEnabled) nextOpening = true;
                UpdateTrayText();
            };

            ToolStripMenuItem resetItem = new ToolStripMenuItem("\u4e0b\u6b21\u8f93\u5165\u5de6\u5f15\u53f7\u300c");
            resetItem.Click += delegate { nextOpening = true; };
            ToolStripMenuItem exitItem = new ToolStripMenuItem("\u9000\u51fa");
            exitItem.Click += delegate { ExitThread(); };
            menu.Items.Add(enabledItem);
            menu.Items.Add(resetItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(exitItem);

            trayIcon = new NotifyIcon
            {
                Icon = SystemIcons.Application,
                ContextMenuStrip = menu,
                Visible = true
            };
            trayIcon.DoubleClick += delegate { enabledItem.Checked = !enabledItem.Checked; };
            UpdateTrayText();

            hookProc = HookCallback;
            IntPtr module = GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName);
            hookHandle = SetWindowsHookEx(WH_KEYBOARD_LL, hookProc, module, 0);
            if (hookHandle == IntPtr.Zero)
            {
                trayIcon.Visible = false;
                trayIcon.Dispose();
                menu.Dispose();
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not install the keyboard hook.");
            }
        }

        public static void Run()
        {
            bool createdNew;
            using (Mutex mutex = new Mutex(true, @"Local\CodexCornerQuoteMapper", out createdNew))
            {
                if (!createdNew) return;
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                try
                {
                    Application.Run(new TrayApplication());
                }
                finally
                {
                    mutex.ReleaseMutex();
                }
            }
        }

        private void UpdateTrayText()
        {
            trayIcon.Text = mappingEnabled ? "Corner quotes: On" : "Corner quotes: Off";
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0)
            {
                int message = wParam.ToInt32();
                bool isDown = message == WM_KEYDOWN || message == WM_SYSKEYDOWN;
                bool isUp = message == WM_KEYUP || message == WM_SYSKEYUP;
                if (isDown || isUp)
                {
                    KBDLLHOOKSTRUCT key = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
                    if ((key.flags & LLKHF_INJECTED) == 0 && key.vkCode == VK_OEM_7)
                    {
                        if (isUp)
                        {
                            quoteKeyHeld = false;
                            if (suppressQuoteRelease)
                            {
                                suppressQuoteRelease = false;
                                return new IntPtr(1);
                            }
                        }
                        else
                        {
                            if (quoteKeyHeld)
                                return suppressQuoteRelease ? new IntPtr(1) : CallNextHookEx(hookHandle, nCode, wParam, lParam);

                            quoteKeyHeld = true;
                            IntPtr foreground = GetForegroundWindow();
                            if (foreground != lastForegroundWindow)
                            {
                                lastForegroundWindow = foreground;
                                nextOpening = true;
                            }
                            bool chineseMode = IsChineseNativeMode();
                            bool shift = IsKeyDown(VK_SHIFT);
                            bool modified = IsKeyDown(VK_CONTROL) || IsKeyDown(VK_MENU) || IsKeyDown(VK_LWIN) || IsKeyDown(VK_RWIN);

                            if (mappingEnabled && chineseMode && shift && !modified)
                            {
                                char value = nextOpening ? '\u300C' : '\u300D';
                                if (SendUnicode(value))
                                {
                                    nextOpening = !nextOpening;
                                    suppressQuoteRelease = true;
                                    return new IntPtr(1);
                                }
                            }
                            else
                            {
                                suppressQuoteRelease = false;
                                if (!chineseMode) nextOpening = true;
                            }
                        }
                    }
                }
            }
            return CallNextHookEx(hookHandle, nCode, wParam, lParam);
        }

        private static bool IsKeyDown(int virtualKey)
        {
            return (GetAsyncKeyState(virtualKey) & 0x8000) != 0;
        }

        private static bool IsChineseNativeMode()
        {
            IntPtr foreground = GetForegroundWindow();
            if (foreground == IntPtr.Zero) return false;

            uint threadId = GetWindowThreadProcessId(foreground, IntPtr.Zero);
            IntPtr target = foreground;
            GUITHREADINFO gui = new GUITHREADINFO();
            gui.cbSize = (uint)Marshal.SizeOf(typeof(GUITHREADINFO));
            if (threadId != 0 && GetGUIThreadInfo(threadId, ref gui) && gui.hwndFocus != IntPtr.Zero)
                target = gui.hwndFocus;

            IntPtr context = ImmGetContext(target);
            if (context == IntPtr.Zero && target != foreground)
            {
                target = foreground;
                context = ImmGetContext(target);
            }
            if (context == IntPtr.Zero)
            {
                IntPtr imeWindow = ImmGetDefaultIMEWnd(target);
                if (imeWindow == IntPtr.Zero && target != foreground)
                    imeWindow = ImmGetDefaultIMEWnd(foreground);
                if (imeWindow == IntPtr.Zero) return false;

                IntPtr openResult;
                IntPtr conversionResult;
                bool openQuery = SendMessageTimeout(imeWindow, WM_IME_CONTROL,
                    (IntPtr)IMC_GETOPENSTATUS, IntPtr.Zero, SMTO_ABORTIFHUNG, 100, out openResult);
                bool conversionQuery = SendMessageTimeout(imeWindow, WM_IME_CONTROL,
                    (IntPtr)IMC_GETCONVERSIONMODE, IntPtr.Zero, SMTO_ABORTIFHUNG, 100, out conversionResult);
                return openQuery && conversionQuery && openResult != IntPtr.Zero &&
                    (((uint)conversionResult.ToInt64() & IME_CMODE_NATIVE) != 0);
            }

            try
            {
                if (!ImmGetOpenStatus(context)) return false;
                uint conversion;
                uint sentence;
                return ImmGetConversionStatus(context, out conversion, out sentence) &&
                    (conversion & IME_CMODE_NATIVE) != 0;
            }
            finally
            {
                ImmReleaseContext(target, context);
            }
        }

        private static bool SendUnicode(char value)
        {
            INPUT down = new INPUT();
            down.type = INPUT_KEYBOARD;
            down.U.ki.wVk = 0;
            down.U.ki.wScan = value;
            down.U.ki.dwFlags = KEYEVENTF_UNICODE;

            INPUT up = new INPUT();
            up.type = INPUT_KEYBOARD;
            up.U.ki.wVk = 0;
            up.U.ki.wScan = value;
            up.U.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

            INPUT[] inputs = new INPUT[] { down, up };
            return SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT))) == (uint)inputs.Length;
        }

        protected override void ExitThreadCore()
        {
            if (hookHandle != IntPtr.Zero)
            {
                UnhookWindowsHookEx(hookHandle);
                hookHandle = IntPtr.Zero;
            }
            if (trayIcon != null)
            {
                trayIcon.Visible = false;
                trayIcon.Dispose();
            }
            if (menu != null) menu.Dispose();
            base.ExitThreadCore();
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct KBDLLHOOKSTRUCT
        {
            public uint vkCode;
            public uint scanCode;
            public uint flags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT
        {
            public int left;
            public int top;
            public int right;
            public int bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct GUITHREADINFO
        {
            public uint cbSize;
            public uint flags;
            public IntPtr hwndActive;
            public IntPtr hwndFocus;
            public IntPtr hwndCapture;
            public IntPtr hwndMenuOwner;
            public IntPtr hwndMoveSize;
            public IntPtr hwndCaret;
            public RECT rcCaret;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MOUSEINPUT
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct INPUTUNION
        {
            [FieldOffset(0)] public MOUSEINPUT mi;
            [FieldOffset(0)] public KEYBDINPUT ki;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct INPUT
        {
            public uint type;
            public INPUTUNION U;
        }

        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc callback, IntPtr module, uint threadId);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool UnhookWindowsHookEx(IntPtr hook);

        [DllImport("user32.dll")]
        private static extern IntPtr CallNextHookEx(IntPtr hook, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string moduleName);

        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int virtualKey);

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr window, IntPtr processId);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetGUIThreadInfo(uint threadId, ref GUITHREADINFO info);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SendMessageTimeout(IntPtr window, uint message, IntPtr wParam,
            IntPtr lParam, uint flags, uint timeout, out IntPtr result);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint count, INPUT[] inputs, int size);

        [DllImport("imm32.dll")]
        private static extern IntPtr ImmGetContext(IntPtr window);

        [DllImport("imm32.dll")]
        private static extern IntPtr ImmGetDefaultIMEWnd(IntPtr window);

        [DllImport("imm32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ImmReleaseContext(IntPtr window, IntPtr context);

        [DllImport("imm32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ImmGetOpenStatus(IntPtr context);

        [DllImport("imm32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ImmGetConversionStatus(IntPtr context, out uint conversion, out uint sentence);
    }
}
'@

try {
    $references = @(
        [System.Windows.Forms.NotifyIcon].Assembly.Location,
        [System.Drawing.Icon].Assembly.Location
    )
    Add-Type -TypeDefinition $source -Language CSharp -ReferencedAssemblies $references
    [CodexCornerQuotes.TrayApplication]::Run()
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.ToString(),
        'Corner Quote Mapper',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
