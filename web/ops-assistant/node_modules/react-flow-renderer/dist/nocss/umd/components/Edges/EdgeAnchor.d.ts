import { FC, HTMLAttributes } from 'react';
import { Position } from '../../types';
export interface EdgeAnchorProps extends HTMLAttributes<HTMLDivElement> {
    position: Position;
    centerX: number;
    centerY: number;
    radius?: number;
}
export declare const EdgeAnchor: FC<EdgeAnchorProps>;
