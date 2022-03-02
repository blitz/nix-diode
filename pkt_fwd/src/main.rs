use clap::Parser;
use log::{debug, info, trace};
use std::error::Error;
use std::fmt::Display;
use std::fs::{File, OpenOptions};
use std::future::Future;
use std::io;
use std::path::{Path, PathBuf};
use std::str::FromStr;
use tokio::io::{split, AsyncReadExt, AsyncWriteExt};
use tokio::{join, try_join};

#[derive(Debug, Clone, PartialEq)]
enum Source {
    // The data source is a listening vsock with the given port number.
    PassiveVsock(u32),

    // The data source is a file.
    File(PathBuf),
}

#[derive(Debug, Clone, PartialEq)]
enum InputError {
    InvalidFormat(String),
}

impl Display for InputError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            InputError::InvalidFormat(token) => write!(f, "Invalid format: {}", &token),
        }
    }
}

impl Error for InputError {}

impl FromStr for Source {
    type Err = InputError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        if let Some(file) = s.strip_prefix("file:") {
            Ok(Source::File(file.into()))
        } else if let Some(port_str) = s.strip_prefix("vsock:") {
            Ok(Source::PassiveVsock(port_str.parse().map_err(|_| {
                InputError::InvalidFormat(port_str.to_owned())
            })?))
        } else {
            Err(InputError::InvalidFormat(s.to_owned()))
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Framedness {
    Framed,
    Unframed,
}

impl FromStr for Framedness {
    type Err = InputError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        if s == "framed" {
            Ok(Framedness::Framed)
        } else if s == "unframed" {
            Ok(Framedness::Unframed)
        } else {
            Err(InputError::InvalidFormat(s.to_owned()))
        }
    }
}

#[derive(Parser, Debug)]
struct Args {
    input_framedness: Framedness,
    input: Source,

    output_framedness: Framedness,
    output: Source,
}

#[derive(Debug, Clone)]
struct Packet {
    size: usize,
    data: [u8; 2040],
}

impl Packet {
    fn new(data: &[u8]) -> Self {
        let mut buffer = [0; 2040];
        (&mut buffer[0..data.len()]).copy_from_slice(data);

        Self {
            size: data.len(),
            data: buffer,
        }
    }

    fn as_slice(&self) -> &[u8] {
        &self.data[0..self.size]
    }
}

impl Default for Packet {
    fn default() -> Self {
        Self {
            size: 0,
            data: [0; 2040],
        }
    }
}

type PacketSink = tokio::sync::mpsc::Sender<Packet>;
type PacketSource = tokio::sync::mpsc::Receiver<Packet>;

/// Read unframed packets from input and writes them framed into output.
async fn read_unframed(
    input: &mut (impl AsyncReadExt + std::marker::Unpin),
    packet_sink: PacketSink,
) -> Result<(), std::io::Error> {
    let mut packet = [0; 2040];

    debug!("Framing forwarding loop running.");
    loop {
        let size: usize = input.read(&mut packet).await?;

        trace!("Read unframed {} byte packet.", size);
        packet_sink
            .send(Packet::new(&packet[0..size]))
            .await
            // XXX
            .map_err(|_| std::io::Error::from_raw_os_error(22))?;
    }
}

/// Forwards framed packets.
async fn read_framed(
    input: &mut (impl AsyncReadExt + std::marker::Unpin),
    packet_sink: PacketSink,
) -> Result<(), std::io::Error> {
    let mut packet = [0; 2040];

    debug!("Forwarding loop running.");
    loop {
        let mut header: [u8; 8] = [0; 8];
        input.read_exact(&mut header).await?;

        let size: usize = u64::from_le_bytes(header).try_into().unwrap();
        assert!(size < packet.len());

        trace!("Read framed {} byte packet.", size);
        input.read_exact(&mut packet[0..size]).await?;

        packet_sink
            .send(Packet::new(&mut packet[0..size]))
            .await
            // XXX
            .map_err(|_| std::io::Error::from_raw_os_error(22))?;
    }
}

async fn write(
    mut packet_source: PacketSource,
    output: &mut (impl AsyncWriteExt + std::marker::Unpin),
    framing: Framedness,
) -> Result<(), std::io::Error> {
    debug!("Write loop running.");
    loop {
        let packet = packet_source
            .recv()
            .await
            // XXX Need a better error type.
            .ok_or(std::io::Error::from_raw_os_error(22))?;

        trace!("Write {:?} {} byte packet.", framing, packet.size);
        let header = u64::try_from(packet.size).unwrap().to_le_bytes();

        match framing {
            Framedness::Framed => output.write_all(&header).await?,
            Framedness::Unframed => {
                // Nothing to be done.
            }
        }

        output.write_all(packet.as_slice()).await?;
    }
}

async fn spawn_vsock(
    port: u32,
    framedness: Framedness,
    packet_source: PacketSource,
    packet_sink: PacketSink,
) -> () {
    assert_eq!(
        framedness,
        Framedness::Framed,
        "Vsocks can only be used with framed packets"
    );

    let mut listener = tokio_vsock::VsockListener::bind(u32::MAX, port).unwrap();

    let (stream, addr) = listener.accept().await.unwrap();
    info!("Accepted connection from {}.", addr);

    let (mut stream_rh, mut stream_wh) = split(stream);

    let read_fut = tokio::spawn(async move { read_framed(&mut stream_rh, packet_sink).await });
    let write_fut =
        tokio::spawn(async move { write(packet_source, &mut stream_wh, Framedness::Framed).await });

    let (read_res, write_res) = try_join!(read_fut, write_fut).unwrap();
    read_res.and(write_res).unwrap();
}

fn open_file(path: &Path) -> io::Result<File> {
    OpenOptions::new().read(true).write(true).open(path)
}

async fn spawn_file(
    file_name: PathBuf,
    framedness: Framedness,
    packet_source: PacketSource,
    packet_sink: PacketSink,
) -> () {
    let file = tokio::fs::File::from_std(open_file(&file_name).unwrap());
    let (mut stream_rh, mut stream_wh) = split(file);

    let read_fut = match framedness {
        Framedness::Framed => {
            tokio::spawn(async move { read_framed(&mut stream_rh, packet_sink).await })
        }
        Framedness::Unframed => {
            tokio::spawn(async move { read_unframed(&mut stream_rh, packet_sink).await })
        }
    };

    let write_fut =
        tokio::spawn(async move { write(packet_source, &mut stream_wh, framedness).await });

    let (read_res, write_res) = try_join!(read_fut, write_fut).unwrap();
    read_res.and(write_res).unwrap();
}

type BoxedFuture = Box<dyn Future<Output = ()> + Unpin>;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    stderrlog::new().verbosity(100).init()?;

    let (inout_sink, inout_source) = tokio::sync::mpsc::channel(16);
    let (outin_sink, outin_source) = tokio::sync::mpsc::channel(16);

    let in_fut: BoxedFuture = match args.input {
        Source::File(file_name) => Box::new(Box::pin(spawn_file(
            file_name,
            args.input_framedness,
            outin_source,
            inout_sink,
        ))),
        Source::PassiveVsock(port) => Box::new(Box::pin(spawn_vsock(
            port,
            args.input_framedness,
            outin_source,
            inout_sink,
        ))),
    };

    let out_fut: BoxedFuture = match args.output {
        Source::File(file_name) => Box::new(Box::pin(spawn_file(
            file_name,
            args.output_framedness,
            inout_source,
            outin_sink,
        ))),
        Source::PassiveVsock(port) => Box::new(Box::pin(spawn_vsock(
            port,
            args.output_framedness,
            inout_source,
            outin_sink,
        ))),
    };

    join!(in_fut, out_fut);

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn source_files_are_parsed() {
        assert_eq!(
            Source::from_str("file:foo.bar"),
            Ok(Source::File(PathBuf::from("foo.bar")))
        );
    }

    #[test]
    fn source_vsocks_are_parsed() {
        assert_eq!(Source::from_str("vsock:123"), Ok(Source::PassiveVsock(123)));
    }
}
