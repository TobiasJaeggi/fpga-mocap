import json
import logging
from pathlib import Path

import click

from commandSender import CommandSender, Fps


def apply_config_file(config_file: Path) -> bool:
    with open(config_file, "r") as f:
        json_doc = json.load(f)

    for ip, settings in json_doc.items():
        logging.debug(f"IP: {ip}")
        command_sender = CommandSender(target_ip=ip)
        for setting, value in settings.items():
            logging.debug(f"{setting}: {value}")
            match setting:
                case "fps":
                    match value:
                        case 13:
                            fps = Fps._13
                        case 72:
                            fps = Fps._72
                        case _:
                            logging.error(f"fps {value} not supported")
                            return False
                    assert command_sender.fps(fps=fps) is True, "fps failed"
                case "exposure":
                    assert command_sender.exposure(level=value) is True, (
                        "exposure failed"
                    )
                case "gain":
                    assert command_sender.gain(level=value, band=0) is True, (
                        "gain failed"
                    )
                case "threshold":
                    assert (
                        command_sender.pipeline_binarization_threshold(threshold=value)
                        is True
                    ), "threshold failed"
                case "light":
                    assert (
                        command_sender.strobe_enable_constant(enable=value) is True
                    ), "light failed"
                case _:
                    logging.error(f"setting {setting} not supported")
                    return False
    return False


@click.command()
@click.argument(
    "FILE",
    required=True,
)
def main(file) -> None:
    apply_config_file(Path(file))


if __name__ == "__main__":
    main()
