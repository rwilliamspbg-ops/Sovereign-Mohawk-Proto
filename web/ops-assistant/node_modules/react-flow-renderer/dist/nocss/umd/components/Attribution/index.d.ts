/// <reference types="react" />
import { AttributionPosition, ProOptions } from '../../types';
declare type AttributionProps = {
    proOptions?: ProOptions;
    position?: AttributionPosition;
};
declare function Attribution({ proOptions, position }: AttributionProps): JSX.Element | null;
export default Attribution;
