import React, { HTMLAttributes } from 'react';
import { HandleProps } from '../../types';
export declare type HandleComponentProps = HandleProps & Omit<HTMLAttributes<HTMLDivElement>, 'id'>;
declare const _default: React.MemoExoticComponent<React.ForwardRefExoticComponent<HandleProps & Omit<React.HTMLAttributes<HTMLDivElement>, "id"> & React.RefAttributes<HTMLDivElement>>>;
export default _default;
