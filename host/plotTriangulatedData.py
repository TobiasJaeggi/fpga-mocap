import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
import typing
import numpy as np
import click

PRIMARY_COLOR: typing.Final = "#1520E8FF"
SECONDARY_COLOR: typing.Final = "#1520E859"

def load(file: Path) -> np.typing.NDArray: # 3xn vecs
    points: np.typing.NDArray = np.empty((3,0))
    with open(file, "r") as f:
        for line in f:
            _, coords = eval(line)
            point = np.array(coords).reshape(3, 1)
            points = np.hstack((points, point))
    return points


@click.command()
@click.argument(
    "FILE",
    required=True,
)
def main(file) -> None:
    points = load(file)

    fig = plt.figure()

    # 3D subplot at [0,0]
    ax00 = fig.add_subplot(2, 2, 1, projection='3d')
    ax00.scatter(points[0,:], points[1,:], points[2,:], marker='o', color=PRIMARY_COLOR)
    #ax.plot(points[0,:], points[1,:], points[2,:], color="#1520E859")

    ax00.set_xlabel('distance X / m')
    ax00.set_ylabel('distance Y / m')
    ax00.set_zlabel('distance Z / m')
    ax00.view_init(45,-45,0)


    # 2D subplot at [0,1]
    ax01 = fig.add_subplot(2, 2, 2)
    ax01.scatter(points[0,:], points[1,:], marker='o', color=PRIMARY_COLOR)
    ax01.set_xlabel('distance X / m')
    ax01.set_ylabel('distance Y / m')
    ax01.set_title('X vs Y')

    # 2D subplot at [1,0]
    ax10 = fig.add_subplot(2, 2, 3)
    ax10.scatter(points[0,:], points[2,:], marker='o', color=PRIMARY_COLOR)
    ax10.set_xlabel('distance X / m')
    ax10.set_ylabel('distance Z / m')
    ax10.set_title('X vs Z')

    # 2D subplot at [1,1]
    ax11 = fig.add_subplot(2, 2, 4)
    ax11.scatter(points[1,:], points[2,:], marker='o', color=PRIMARY_COLOR)
    ax11.set_xlabel('distance Y / m')
    ax11.set_ylabel('distance Z / m')
    ax11.set_title('Y vs Z')

    plt.show()

if __name__ == "__main__":
    main()
cc