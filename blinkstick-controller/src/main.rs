
#![allow(dead_code, unused_variables)]

#[tokio::main(flavor = "multi_thread", worker_threads = 2)]
async fn main() {
    let mut ps = PollState::default();
    loop {
        match detect_hw_events(&mut ps).await {
            Ok(hw_event_occurred) => {
                if hw_event_occurred {
                    if let Err(e) = update_lights(&mut ps).await {
                        eprintln!("{:?}", e);
                    }
                }
                else {
                    // No news, briefly sleep
                    tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
                }
            }
            Err(e) => {
                eprintln!("{:?}", e);
                // Error, loudly sleep
                tokio::time::sleep(tokio::time::Duration::from_millis(2400)).await;
            }
        }
    }
}

#[derive(Default)]
struct PollState {
    pub gpu_is_connected: bool,

    // empty string == off
    pub tmp_file_contents: [String; 7],

    pub blinkstick: Option<blinkstick::BlinkStick>,
}

async fn detect_hw_events(ps: &mut PollState) -> Result<bool, Box<dyn std::error::Error>> {
    if ps.blinkstick.is_none() {
        return Ok(true); // Not having a blinkstick initialized is a HW event
    }



    Ok(false)
}

async fn update_lights(ps: &mut PollState) -> Result<(), Box<dyn std::error::Error>> {
    if ps.blinkstick.is_none() {
        ps.blinkstick = Some(blinkstick::BlinkStick::find_first()?);
    }


    Ok(())
}

async fn update_all_tmp_files(ps: &mut PollState) -> Result<bool, Box<dyn std::error::Error>> {

    for i in 2..=7 {
        let p: std::path::PathBuf = format!("/tmp/blink{i}").into();
        if p.exists() {

        }
        else {

        }
    }

    Ok(false)
}

