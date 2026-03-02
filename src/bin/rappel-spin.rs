use spinners::{Spinner, Spinners, Stream};
use std::env;
use std::io::{self, IsTerminal, Write};
use std::process::{self, Command, Stdio};
use std::thread;
use std::time::Duration;

const DISABLE_ENV: &str = "RAPPEL_NO_SPINNER";

fn main() {
    if let Err(err) = run() {
        eprintln!("{err}");
        process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let args = env::args().skip(1).collect::<Vec<_>>();
    let mode = parse_args(args)?;

    match mode {
        Mode::WaitPid { title, pid } => {
            let mut spinner = SpinnerGuard::start(spinner_enabled(), &title);
            while process_exists(pid).map_err(|err| err.to_string())? {
                thread::sleep(Duration::from_millis(100));
            }
            spinner.stop();
            Ok(())
        }
        Mode::RunCommand {
            title,
            command,
            args,
        } => {
            let mut spinner = SpinnerGuard::start(spinner_enabled(), &title);
            let status = Command::new(&command)
                .args(&args)
                .stdin(Stdio::null())
                .stdout(Stdio::inherit())
                .stderr(Stdio::inherit())
                .status()
                .map_err(|err| format!("rappel-spin: failed to execute {command}: {err}"))?;
            spinner.stop();
            process::exit(status.code().unwrap_or(1));
        }
    }
}

enum Mode {
    WaitPid { title: String, pid: u32 },
    RunCommand {
        title: String,
        command: String,
        args: Vec<String>,
    },
}

fn parse_args(args: Vec<String>) -> Result<Mode, String> {
    if args.is_empty() {
        return Err(String::from(
            "usage: rappel-spin --title <text> (--pid <pid> | -- <command> [args...])",
        ));
    }

    let mut iter = args.into_iter();
    let mut title = String::from("Operation en cours...");
    let mut pid: Option<u32> = None;

    while let Some(arg) = iter.next() {
        match arg.as_str() {
            "--title" => {
                title = iter
                    .next()
                    .ok_or_else(|| String::from("rappel-spin: missing value after --title"))?;
            }
            "--pid" => {
                let raw = iter
                    .next()
                    .ok_or_else(|| String::from("rappel-spin: missing value after --pid"))?;
                pid = Some(
                    raw.parse::<u32>()
                        .map_err(|_| format!("rappel-spin: invalid pid: {raw}"))?,
                );
            }
            "--" => {
                let command = iter
                    .next()
                    .ok_or_else(|| String::from("rappel-spin: missing command after --"))?;
                let rest = iter.collect::<Vec<_>>();
                return Ok(Mode::RunCommand {
                    title,
                    command,
                    args: rest,
                });
            }
            _ => return Err(format!("rappel-spin: unexpected argument: {arg}")),
        }
    }

    if let Some(pid) = pid {
        return Ok(Mode::WaitPid { title, pid });
    }

    Err(String::from(
        "rappel-spin: missing --pid or wrapped command",
    ))
}

fn spinner_enabled() -> bool {
    io::stderr().is_terminal() && !env_truthy(DISABLE_ENV)
}

fn env_truthy(name: &str) -> bool {
    matches!(
        env::var(name),
        Ok(value)
            if matches!(
                value.trim().to_ascii_lowercase().as_str(),
                "1" | "true" | "yes" | "on"
            )
    )
}

fn spinner_color() -> &'static str {
    match env::var("ZSH_THEME_MODE") {
        Ok(mode) if mode.eq_ignore_ascii_case("light") => "\x1b[38;2;100;74;201m",
        _ => "\x1b[38;2;189;147;249m",
    }
}

fn process_exists(pid: u32) -> io::Result<bool> {
    let status = Command::new("/bin/kill")
        .arg("-0")
        .arg(pid.to_string())
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;
    Ok(status.success())
}

struct SpinnerGuard {
    inner: Option<Spinner>,
}

impl SpinnerGuard {
    fn start(enabled: bool, title: &str) -> Self {
        if enabled {
            let title = format!("{}{}\x1b[0m", spinner_color(), title);
            Self {
                inner: Some(Spinner::with_stream(Spinners::Dots, title, Stream::Stderr)),
            }
        } else {
            Self { inner: None }
        }
    }

    fn stop(&mut self) {
        if let Some(spinner) = self.inner.as_mut() {
            spinner.stop();
            let _ = write!(io::stderr(), "\r\x1b[2K");
            let _ = io::stderr().flush();
        }
        self.inner = None;
    }
}

impl Drop for SpinnerGuard {
    fn drop(&mut self) {
        self.stop();
    }
}

