use clap::Parser;
use log::info;
use std::fs::{File, OpenOptions};
use std::io;
use std::path::{Path, PathBuf};
use tokio::io::{split, AsyncReadExt, AsyncWrite, AsyncWriteExt};

/// Simple program to greet a person
#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    /// Name of the person to greet
    #[clap(long)]
    input: PathBuf,

    /// Number of times to greet
    #[clap(long)]
    output: PathBuf,
}

fn open_tap(path: &Path) -> io::Result<File> {
    OpenOptions::new().read(true).write(true).open(path)
}

async fn packet_forward(
    input: &mut (impl AsyncReadExt + std::marker::Unpin),
    output: &mut (impl AsyncWrite + std::marker::Unpin),
) -> Result<(), tokio::io::Error> {
    let mut packet = [0; 2048];

    info!("Forwarding loop running.");
    loop {
        let bytes = input.read(&mut packet).await?;
        output.write_all(&packet[0..bytes]).await?;
    }
}

fn spawn_forwarder(
    input: impl AsyncReadExt + AsyncWriteExt + std::marker::Unpin + Send + 'static,
    output: impl AsyncReadExt + AsyncWriteExt + std::marker::Unpin + Send + 'static,
) -> Result<(), Box<dyn std::error::Error>> {
    let (mut input_rh, mut input_wh) = split(input);
    let (mut output_rh, mut output_wh) = split(output);

    tokio::spawn(async move { packet_forward(&mut input_rh, &mut output_wh).await });
    tokio::spawn(async move { packet_forward(&mut output_rh, &mut input_wh).await });

    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    stderrlog::new().module(module_path!()).init().unwrap();

    let input = tokio::fs::File::from_std(open_tap(&args.input)?);
    let output = tokio::fs::File::from_std(open_tap(&args.output)?);

    spawn_forwarder(input, output)?;

    Ok(())
}
